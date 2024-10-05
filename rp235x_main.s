.syntax unified
.cpu cortex-m33
.fpu fpv5-sp-d16
.thumb 

.include "rp235x_defines.S"

// @-----------------------------------------------------------------------------------------------------------------------------------
.macro deassert_peri_reset, a0, t0, t1, bit_pos
deassert_peri\bit_pos : 
    ldr \a0, =RESETS_RESET_CLR
    mov \t0, #(1 << \bit_pos)
    str \t0, [\a0] 

    ldr \a0, =RESETS_RESET_DONE_RW
loop_deassert_done_peri\bit_pos :
    ldr \t1, [\a0]
    // and \t1, \t1, \t0
    // cmp \t1, \t0
    tst \t0, \t1
    beq loop_deassert_done_peri\bit_pos
.endm

// @-----------------------------------------------------------------------------------------------------------------------------------
.global secure_fault_handler
secure_fault_handler :
.global usage_fault_handler
usage_fault_handler :
.global bus_fault_handler
bus_fault_handler :
.global memmanage_fault_handler
memmanage_fault_handler :
.global NMI_fault_handler
NMI_fault_handler :
.global hard_fault_handler
hard_fault_handler : // Doesn't do anything, just exit right away
    push {lr}
    pop {pc}
// @-----------------------------------------------------------------------------------------------------------------------------------
.global uart0_interrupt_handler
uart0_interrupt_handler :

    // clear the interrupt 
    // TODO(gh) clear the overun bit just in case we missed the characters?
    adr.n r3, #uart0_data
    ldm r3, {r1, r2, r12}
    movs.n r0, #(1 << 4) // RXIC
    .align

    str.w r0, [r12, #UART_UARTICR_OFFSET] // UART0ICR

    sub.w r12, 0x2000 // #((UART0_SET_BASE+UART_UARTICR_OFFSET) - (UART0_BASE+UART_UARTDR_OFFSET)) 
    ldrb.w r0, [r12] // read a byte from the UART0DR fifo

    orr.w r1, r0, r1, lsl #8 // shift the current buffer left by 8 and then OR in the new character
    cmp.n r2, r1
     itt ne
    strne.n r1, [r3]
     bxne.n lr // exit if the buffer doesn't match the sequence

uart0_interrupt_handler_reboot :
    // use the ROM's lookup function to find the reboot api,
    // we can trash lr since we are going to reboot anyway
    mov.w lr, #ROM_TABLE_LOOKUP_VAL_OFFSET
    ldrh.w lr, [lr] // load the function pointer(2 bytes) that finds the reboot function
    mov.w r0, #('R' | ('B' << 8)) // param 0 = lookup code
    .align
    movs.n r1, #RT_FLAG_FUNC_ARM_SEC // param 1 = secure / non-secure
     blx.n lr // jump to https://github.com/raspberrypi/pico-bootrom-rp2350/blob/451edbcd769770f92ce265c05d6c36ad040994fa/src/main/arm/arm8_bootrom_rt0.S#L84

    // call the reboot function
    mov.n lr, r0 // should use r0 as function argument, so move the pointer to lr
    mov.w r0, #(ROM_REBOOT_TYPE_BOOTSEL | ROM_REBOOT_FLAG_NO_RETURN_ON_SUCCESS) // flags, reboot in bootsel mode in ARM, no return on succses
    movs.n r1, #10 // delay_ms, 10ms is the value that picosdk is using
    movs.n r2, #0 // p0
    .align
    movs.n r3, #0 // p1 
     blx lr 

uart0_data:
    .word 0 // uart0_magic_write_buffer
    .word (('R') | ('G' << 8) | ('A' << 16) | ('M' << 24))  // magic sequence is MAGR
    .word UART0_SET_BASE // uart0 ptr

// @-----------------------------------------------------------------------------------------------------------------------------------

.align
// gnu assembler entry point
.global _start
_start:
// @-----------------------------------------------------------------------------------------------------------------------------------
// M33 initialization
// @-----------------------------------------------------------------------------------------------------------------------------------

    // thread mode uses MSP as the initial stack pointer, which has the value that we provided at the start of the vector table.
    // we can use the CONTROL register to  change the thread mode to use PSP instead of MSP
    movs.n r0, #(1<<1) 
    msr control, r0
    isb // required by ARM
    ldr sp, =0x20040000  // set the PSP 

// @-----------------------------------------------------------------------------------------------------------------------------------
configure_all_output_gpios :
    ldr r7, =SIO_BASE
    movs.n r1, #((1<<2) | (1<<3) | (1<<4) | (1<<5)) // OR in the bits of the gpio
disable_output_enable_and_clear_output :
    str r1, [r7, #SIO_GPIO_OE_CLR_OFFSET]
    str r1, [r7, #SIO_GPIO_OUT_CLR_OFFSET]

set_input_enable :
    ldr.n r6, =PADS_BANK0_SET
    movs.n r0, #(1<<6) // 6 = IE: Input enable
    str.n r0, [r6, #PADS_BANK0_GPIO2_OFFSET]
    str.n r0, [r6, #PADS_BANK0_GPIO3_OFFSET]
    str.n r0, [r6, #PADS_BANK0_GPIO4_OFFSET]
    str.n r0, [r6, #PADS_BANK0_GPIO5_OFFSET]

set_gpio_function :
    ldr.n r6, =IO_BANK0_BASE

    movs.n r0, #GPIO_FUNCSEL_SIO
    str.n r0, [r6, #GPIO2_CTRL_OFFSET]

    movs.n r0, #GPIO_FUNCSEL_PIO0
    str.n r0, [r6, #GPIO3_CTRL_OFFSET]
    str.n r0, [r6, #GPIO4_CTRL_OFFSET]
    str.n r0, [r6, #GPIO5_CTRL_OFFSET]

remove_pad_isolation_control : // This should come _AFTER_ we configure the GPIO
    ldr.n r6, =PADS_BANK0_CLR
    mov.w r0, #(1<<8) // 8 = ISO: Pad isolation control
    str.n r0, [r6, #PADS_BANK0_GPIO2_OFFSET]
    str.n r0, [r6, #PADS_BANK0_GPIO3_OFFSET]
    str.n r0, [r6, #PADS_BANK0_GPIO4_OFFSET]
    str.n r0, [r6, #PADS_BANK0_GPIO5_OFFSET]

enable_output_gpio :
    str.n r1, [r7, #SIO_GPIO_OE_SET_OFFSET]

// @-----------------------------------------------------------------------------------------------------------------------------------
#define xosc_base           r7
#define xosc_set_base       r6
    
#define xosc_enable_value r1
#define xosc_delay_counter  r0
set_xosc_startup_delay : 
    ldr xosc_base, =XOSC_BASE
    ldr xosc_set_base, =XOSC_SET_BASE
    //mov xosc_delay_counter, #0xf4 // 1ms delay
    //str xosc_delay_counter, [xosc_base, #XOSC_STARTUP_OFFSET]
enable_xosc:
    ldr xosc_enable_value, =0xaa0 // 1-15Mhz
    str xosc_enable_value, [xosc_base, #XOSC_CTRL_OFFSET]
    ldr xosc_enable_value, =0xFAB000 // enable
    str xosc_enable_value, [xosc_set_base, #XOSC_CTRL_OFFSET] 

#undef xosc_delay_counter  
#undef xosc_enable_value 

#define xosc_stable_bit r0
#define xosc_status     r1
wait_until_xosc_stable : 
loop_until_xosc_stable : 
    ldr xosc_status, [xosc_base, #XOSC_STATUS_OFFSET]
    lsrs xosc_status, #31
    beq loop_until_xosc_stable 
#undef xosc_stable_bit
#undef xosc_status  

#define clk_set_base r7
#define clk_ref_src r0
#define clk_sys_src r1
switch_to_xosc :
	ldr clk_set_base, =CLOCKS_BASE
	movs clk_ref_src, #2			// clk_ref source = XOSC
	str clk_ref_src, [clk_set_base, #CLK_REF_CTRL_OFFSET]
	movs clk_sys_src, #0			// clk_sys source = clk_ref
	str clk_sys_src, [clk_set_base, #CLK_SYS_CTRL_OFFSET]	
#undef clk_set_base
#undef clk_ref_src
#undef clk_sys_src

// since both clk_ref and clk_sys are running off the XOSC, 
// now we can turn off the ROSC to save power.
#define rosc_base r7
#define rosc_dormant_value r0
stop_rosc : 
    ldr rosc_base, =ROSC_BASE
    ldr rosc_dormant_value, =ROSC_DORMANT_VALUE
    str rosc_dormant_value, [rosc_base, #ROSC_DORMANT_OFFSET]

#undef xosc_base           
#undef xosc_set_base       

// @-----------------------------------------------------------------------------------------------------------------------------------
#if 1 // enable/disable pll
/*
    PLL programming sequence 
    • Program the FBDIV(feedback divider)
    • Turn on the main power and VCO
    • Wait for the VCO to lock (i.e. keep its output frequency stable)
    • Set up post dividers and turn them on

    result = (FREF / REFDIV) × FBDIV / (POSTDIV1 × POSTDIV2)
    120Mhz = (12Mhz / 1) × 100 / (5 × 2)
    150Mhz = (12Mhz / 1) × 150 / (6 × 2)
    
    FREF is always drived from XOSC(12Mhz for the pico)
    REFDIV is normally 1
    FBDIV - the bigger the better accuracy but with higher power consumption
    POSDIV1 should be bigger than POSTDIV2 for lower power consumption
*/
    deassert_peri_reset r7, r0, r1, 14

#define pll_sys_base  r7
#define pll_sys_clr_base r6
    ldr pll_sys_base, =PLL_SYS_BASE
    ldr pll_sys_clr_base, =PLL_SYS_CLR_BASE

#define FBDIV r0
configure_feedback_divider : 
    movs FBDIV, #150
    str FBDIV, [pll_sys_base, #PLL_SYS_FBDIV_INT_OFFSET]
#undef FBDIV

#define POSDIV1 r0
#define POSDIV2 r1
configure_post_dividers : 
    movs POSDIV1, #6
    lsls POSDIV1, #16
    movs POSDIV2, #2 
    lsls POSDIV2, #12
    orrs POSDIV1, POSDIV2
    str POSDIV1, [pll_sys_base, #PLL_SYS_PRIM_OFFSET]
#undef POSDIV1
#undef POSDIV2

#define VCOPD r0
#define PD r1
power_on_main_power_and_vco : 
    movs.n VCOPD, #(1 << 5)
    movs PD, #1
    orrs PD, VCOPD
    str PD, [pll_sys_clr_base, #PLL_SYS_PWR_OFFSET]
#undef VCOPD
#undef PD

#define pll_sys_ctrl_reg r1
wait_vco_lock : 
loop_wait_vco_lock : 
    ldr pll_sys_ctrl_reg, [pll_sys_base, #PLL_SYS_CS_OFFSET]
    lsrs pll_sys_ctrl_reg, #31 // lock bit == bit31
    beq loop_wait_vco_lock 
#undef pll_sys_ctrl_reg

#define POSTDIVPD r0
turn_on_post_dividers : 
    movs.n POSTDIVPD, #(1 << 3)
    str POSTDIVPD, [pll_sys_clr_base, #PLL_SYS_PWR_OFFSET]
#undef POSTDIVPD

#undef pll_sys_base
#undef pll_sys_clr_base
// @-----------------------------------------------------------------------------------------------------------------------------------
// configure clk_sys and clk_peri
// @-----------------------------------------------------------------------------------------------------------------------------------

#define clocks_base r7
#define clk_sys_auxsrc r0
switch_clk_sys_auxsrc : 
    ldr clocks_base, =CLOCKS_BASE
    movs clk_sys_auxsrc, #(0x0<<5) // clksrc_pll_sys
    str clk_sys_auxsrc, [clocks_base, #CLK_SYS_CTRL_OFFSET]
#undef clocks_base
#undef clk_sys_auxsrc

#define clocks_set_base r7
#define clk_sys_ctrl0 r0
switch_to_pll_sys :
    ldr clocks_set_base, =CLOCKS_SET_BASE
    movs clk_sys_ctrl0, #1 // clksrc_clk_sys_aux
    str clk_sys_ctrl0, [clocks_set_base, #CLK_SYS_CTRL_OFFSET]
#undef clocks_set_base
#undef clk_sys_ctrl0

    // configure the source clock for clk_peri and enable it
#define clocks_set_base r7
configure_and_enable_clk_peri : 
    ldr clocks_set_base, =CLOCKS_SET_BASE
    movs r0, #(0x4<<5) // use XOSC as source clock for the peripherals
    str r0, [clocks_set_base, #CLK_PERI_CTRL_OFFSET]

    movs r0, #(1 << 11)
    str r0, [clocks_set_base, #CLK_PERI_CTRL_OFFSET]
#undef clocks_set_base

#endif // disable_pll_sys

// @-----------------------------------------------------------------------------------------------------------------------------------
#define reset_clr_addr r7
#define reset_bits r0
deassert_iobank0_pad0_reset :
    ldr reset_clr_addr, =RESETS_RESET_CLR
    mov reset_bits, #(1<<6)|(1<<9) // iobank 0, pads bank 0
    str reset_bits, [reset_clr_addr] 
#undef reset_clr_addr
#undef reset_bits

#define reset_done_addr r7
#define reset_done r0

    ldr reset_done_addr, =RESETS_RESET_DONE_RW
wait_until_reset_is_done : 
    ldr reset_done, [reset_done_addr]
    and reset_done, reset_done, #(1<<6)|(1<<9)
    cmp reset_done, #(1<<6)|(1<<9)
    bne wait_until_reset_is_done
#undef reset_done_addr
#undef reset_done

// @-----------------------------------------------------------------------------------------------------------------------------------
// @-----------------------------------------------------------------------------------------------------------------------------------
// initialize UART using gpio 0(tx) and 1(rx)


    deassert_peri_reset r7, r0, r1, 26 // deassert uart 0

#define uart0_set_base r7
#define baud_rate_fdiv r3
#define baud_rate_idiv r2
#define baud_rate r1
#define baud_rate_div r0

    ldr uart0_set_base, =UART0_SET_BASE
    ldr r6, =UART0_BASE
set_uart0_baudrate :
    // 115200 baud rate
    movs r0, #6 // ibrd
    str r0, [r6, #UART_UARTIBRD_OFFSET]
    movs r0, #33 // fbrd
    str r0, [r6, #UART_UARTFBRD_OFFSET]

configure_and_enable_uart0 :
    /*
        b[1] PEN: Parity enable
        b[4] FEN: Enable FIFOs
        b[5] WLEN: Word length
     */
    // ldr r0, =((1 << 4) + ((8-5) << 5))
    ldr r0, =(((8-5) << 5))
    str r0, [r6, #UART_UARTLCR_H_OFFSET]

    /*
        b[0] UARTEN: UART enable
        b[8] TXE: Transmit enable
        b[9] RXE: Receive enable
     */
    ldr r0, =((1 << 9) + (1 << 8) + (1 << 0))
    str r0, [r6, #UART_UARTCR_OFFSET]

input_enable : // TODO(gh) seems like we have to do this both for GPIO in and out(i.e uart tx and rx)
    ldr r7, =PADS_BANK0_SET
    ldr r0, =(1<<6)
    str r0, [r7, #PADS_BANK0_GPIO0_OFFSET] // tx
    str r0, [r7, #PADS_BANK0_GPIO1_OFFSET] // rx

funcsel_uart :
    ldr r6, =IO_BANK0_BASE
    movs r0, #GPIO_FUNCSEL_UART
    str r0, [r6, #GPIO0_CTRL_OFFSET]
    str r0, [r6, #GPIO1_CTRL_OFFSET]

remove_iso : // This should come _AFTER_ we configure the GPIO
    ldr r7, =PADS_BANK0_CLR
    movs r0, #(1<<8) // 8 = ISO: Pad isolation control
    str r0, [r7, #PADS_BANK0_GPIO0_OFFSET]
    str r0, [r7, #PADS_BANK0_GPIO1_OFFSET]
 
/*
    Our vtable is already fully populated!
    Enable the interrupt on core0 so that the core can get the interrupt
    general sequenece is from here : https://github.com/raspberrypi/pico-sdk/blob/efe2103f9b28458a1615ff096054479743ade236/src/rp2_common/hardware_irq/irq.c#L78
*/
configure_m33_interrupt :
    ldr r7, =(M33_BASE + M33_NVIC_ICPR1_OFFSET)
    movs r0, #(1<<1)
    str r0, [r7] 

    ldr r7, =(M33_BASE + M33_NVIC_ISER1_OFFSET)
    str r0, [r7] // set the interrupt enable

// configure uart interrupt(interrupt 33) and enable it
configure_uart_interrupt :
    // don't need to configure the fifo since we disabled it for now
    //ldr r7, =UART0_CLR_BASE
    //movs.n r0, #(2 << 3) // rx fifo waterfill = 4 bytes, see the chart in [1] section 12.1.5.
    //str r0, [r7, #UART_UARTIFLS_OFFSET] 

    ldr r7, =UART0_SET_BASE
    movs r0, #((1<<4))// only enable RXIM: Receive interrupt mask
    str r0, [r7, #UART_UARTIMSC_OFFSET]
// @-----------------------------------------------------------------------------------------------------------------------------------
#define sio_base r5
#define bit2 r1

    ldr.w sio_base, =SIO_BASE
    movs.n bit2, #(1<<2);
.align

wiggle_gpio2 : // Are we alive and well? 
    str.n bit2, [sio_base, #SIO_GPIO_OUT_CLR_OFFSET]
    adds.n r0, #0
    adds.n r0, #0

    str.n bit2, [sio_base, #SIO_GPIO_OUT_SET_OFFSET]
    adds.n r2, #0
     b.n wiggle_gpio2


    

