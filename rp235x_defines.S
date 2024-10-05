// 
/*
    NOTE(gh) Reference numbers
    [1] rp2350 datasheet
    [2] Definitive Guide to Arm Cortex-M23 and Cortex-M33 Processors
    [3] Graphics Programming Black Book by Michael Abrash
*/

// constants 

// IMPORTANT(gh) Different GPIOs have different capability, 
// make sure to check the GPIO before configuring it's FUNCSEL
.equ GPIO_FUNCSEL_SPI, 0x01
.equ GPIO_FUNCSEL_UART, 0x02
.equ GPIO_FUNCSEL_I2C, 0x03
.equ GPIO_FUNCSEL_PWM, 0x04
.equ GPIO_FUNCSEL_SIO, 0x05
.equ GPIO_FUNCSEL_PIO0, 0x06
.equ GPIO_FUNCSEL_PIO1, 0x07
.equ GPIO_FUNCSEL_PIO2, 0x08
.equ GPIO_FUNCSEL_NULL, 0x1f

/*
    IMPORTANT!
    The following registers do not support atomic register access:
    - SIO (Section 3.1), though some individual registers (e.g. GPIO) have set, clear, and XOR aliases
    - Any register accessed through the self-hosted CoreSight window, including Arm Mem-APs and the RISC-V Debug Module
    - Standard Arm control registers on the Cortex-M33 private peripheral bus (PPB), except for Raspberry Pi-specific registers on the EPPB
    - OTP programming registers accessed through the SBPI bridge
 */
.equ XOR_OFFSET, (0x1000)
.equ SET_OFFSET, (0x2000)
.equ CLR_OFFSET, (0x3000)

// addresses, these will be stored at the end of the instruction stream
// as they are too large
.equ RESETS_BASE, (0x40020000) // 1 == peripheral is in reset
.equ RESETS_RESET_SET, (RESETS_BASE + SET_OFFSET)
.equ RESETS_RESET_CLR, (RESETS_BASE + CLR_OFFSET)
.equ RESETS_RESET_DONE_RW, (RESETS_BASE + RESETS_RESET_DONE_OFFSET)

.equ RESETS_RESET_DONE_OFFSET, (0x8)


/* ROM */
.equ RT_FLAG_FUNC_ARM_SEC,              (0x0004)
.equ RT_FLAG_FUNC_ARM_NONSEC,           (0x0004)

.equ ROM_TABLE_LOOKUP_VAL_OFFSET,       (0x00000016) 
.equ ROM_TABLE_LOOKUP_ENTRY_OFFSET,     (0x00000018)
.equ ROM_REBOOT_TYPE_NORMAL,            (0x0000)
.equ ROM_REBOOT_TYPE_BOOTSEL,           (0x0002)
.equ ROM_REBOOT_TYPE_RAM_IMAGE,         (0x0003)
.equ ROM_REBOOT_TYPE_FLASH_UPDATE,      (0x0004)
.equ ROM_REBOOT_TYPE_PC_SP,             (0x000d)
.equ ROM_REBOOT_FLAG_NO_RETURN_ON_SUCCESS, (0x100)

/* CLK */
.equ CLOCKS_BASE, (0x40010000)
.equ CLOCKS_XOR_BASE, (0x40010000 + XOR_OFFSET)
.equ CLOCKS_SET_BASE, (0x40010000 + SET_OFFSET)
.equ CLOCKS_CLR_BASE, (0x40010000 + CLR_OFFSET)

.equ CLK_REF_CTRL_OFFSET, (0x30)
.equ CLK_SYS_CTRL_OFFSET, (0x3C)
.equ CLK_PERI_CTRL_OFFSET, (0x48)

/* PLL_SYS */
.equ PLL_SYS_BASE, (0x40050000)
.equ PLL_SYS_XOR_BASE, (PLL_SYS_BASE + XOR_OFFSET)
.equ PLL_SYS_SET_BASE, (PLL_SYS_BASE + SET_OFFSET)
.equ PLL_SYS_CLR_BASE, (PLL_SYS_BASE + CLR_OFFSET)

.equ PLL_SYS_CS_OFFSET,            (0x0)
.equ PLL_SYS_PWR_OFFSET,           (0x4)
.equ PLL_SYS_FBDIV_INT_OFFSET,     (0x8)
.equ PLL_SYS_PRIM_OFFSET,          (0xc)

/* syscfg */
.equ SYSCFG_BASE, (0x40008000)
.equ SYSCFG_PROC_IN_SYNC_BYPASS, (SYSCFG_BASE + 0x04)

/* ROSC */
.equ ROSC_BASE, (0x400e8000)
.equ ROSC_XOR_BASE, (ROSC_BASE + XOR_OFFSET)
.equ ROSC_SET_BASE, (ROSC_BASE + SET_OFFSET)
.equ ROSC_CLR_BASE, (ROSC_BASE + CLR_OFFSET)

.equ ROSC_CTRL_OFFSET,      (0x0)
.equ ROSC_FREQA_OFFSET,     (0x4)
.equ ROSC_FREQB_OFFSET,     (0x8)
.equ ROSC_RANDOM_OFFSET,    (0xc)
.equ ROSC_DORMANT_OFFSET,   (0x10)
.equ ROSC_DIV_OFFSET,       (0x14)
.equ ROSC_PHASE_OFFSET,     (0x18)
.equ ROSC_STATUS_OFFSET,    (0x1c)
.equ ROSC_RANDOMBIT_OFFSET, (0x20)
.equ ROSC_COUNT_OFFSET,     (0x24)

.equ ROSC_DORMANT_VALUE, (0x636f6d61)
.equ ROSC_WAKE_VALUE, (0x77616b65)

/* XOSC */
.equ XOSC_BASE, (0x40048000)
.equ XOSC_XOR_BASE, (XOSC_BASE + XOR_OFFSET)
.equ XOSC_SET_BASE, (XOSC_BASE + SET_OFFSET)
.equ XOSC_CLR_BASE, (XOSC_BASE + CLR_OFFSET)

.equ XOSC_CTRL_OFFSET, 0x00
.equ XOSC_STATUS_OFFSET, 0x04
.equ XOSC_STARTUP_OFFSET, 0x0C
.equ XOSC_COUNT_OFFSET, 0x10

/* SIO */
.equ SIO_BASE, (0xd0000000)
.equ SIO_XOR_BASE, (SIO_BASE + XOR_OFFSET)
.equ SIO_SET_BASE, (SIO_BASE + SET_OFFSET)
.equ SIO_CLR_BASE, (SIO_BASE + CLR_OFFSET)
.equ SIO_GPIO_OUT_OFFSET, (0x10) 
.equ SIO_GPIO_OUT_SET_OFFSET, (0x18) 
.equ SIO_GPIO_OUT_CLR_OFFSET, (0x20)  
.equ SIO_GPIO_OUT_XOR_OFFSET, (0x28) 
.equ SIO_GPIO_OE_SET_OFFSET, (0x38) 
.equ SIO_GPIO_OE_CLR_OFFSET, (0x40)

.equ SIO_GPIO_IN, (SIO_BASE + 0x004) // SIO_BASE + GPIO_IN
.equ SIO_INTERP0_BASE0_OFFSET, (0x088)
.equ SIO_INTERP0_CTRL_LANE0_OFFSET, (0x0ac)
.equ SIO_INTERP0_ACCUM0_OFFSET, (0x080)
.equ SIO_INTERP0_PEEK_LANE0_OFFSET, (0x0a0)

/* Timers */
.equ TIMER0_BASE, (0x400b0000)
.equ TIMER1_BASE, (0x400b8000)
.equ TIMER_TIMEHW_OFFSET, (0x00)
.equ TIMER_TIMELW_OFFSET, (0x04)
.equ TIMER_TIMEHR_OFFSET, (0x08)
.equ TIMER_TIMELR_OFFSET, (0x0c)
.equ TIMER_ALARM0_OFFSET, (0x10)
.equ TIMER_ALARM1_OFFSET, (0x14)
.equ TIMER_ALARM2_OFFSET, (0x18)
.equ TIMER_ALARM3_OFFSET, (0x1c)
.equ TIMER_ARMED_OFFSET, (0x20)
.equ TIMER_TIMERAWH_OFFSET, (0x24)
.equ TIMER_TIMERAWL_OFFSET, (0x28)
.equ TIMER_DBGPAUSE_OFFSET, (0x2c)
.equ TIMER_PAUSE_OFFSET, (0x30)
.equ TIMER_LOCKED_OFFSET, (0x34)
.equ TIMER_SOURCE_OFFSET, (0x38)
.equ TIMER_INTR_OFFSET, (0x3c)
.equ TIMER_INTE_OFFSET, (0x40)
.equ TIMER_INTF_OFFSET, (0x44)
.equ TIMER_INTS_OFFSET, (0x48)

/* UART */
// 32×8 TX and 32×12 RX FIFOs
.equ UART0_BASE, (0x40070000)
.equ UART0_XOR_BASE, (UART0_BASE + XOR_OFFSET)
.equ UART0_SET_BASE, (UART0_BASE + SET_OFFSET)
.equ UART0_CLR_BASE, (UART0_BASE + CLR_OFFSET)
.equ UART1_BASE, (0x40078000)
.equ UART1_XOR_BASE, (UART1_BASE + XOR_OFFSET)
.equ UART1_SET_BASE, (UART1_BASE + SET_OFFSET)
.equ UART1_CLR_BASE, (UART1_BASE + CLR_OFFSET)

.equ UART_UARTDR_OFFSET,        (0x000)
.equ UART_UARTRSR_OFFSET,       (0x004)

.equ UART_UARTFR_OFFSET,        (0x018)
.equ UART_UARTILPR_OFFSET,      (0x020)
.equ UART_UARTIBRD_OFFSET,      (0x024)
.equ UART_UARTFBRD_OFFSET,      (0x028)
.equ UART_UARTLCR_H_OFFSET,     (0x02c)

.equ UART_UARTCR_OFFSET,        (0x030)
.equ UART_UARTIFLS_OFFSET,      (0x034) // Interrupt FIFO Level Select Register
.equ UART_UARTIMSC_OFFSET,      (0x038) // Interrupt Mask Set/Clear Register
.equ UART_UARTRIS_OFFSET,       (0x03c) // Raw Interrupt Status Register
.equ UART_UARTMIS_OFFSET,       (0x040) // Masked Interrupt Status Register
.equ UART_UARTICR_OFFSET,       (0x044) // Interrupt Clear Register

/* SPI */
// 16×8 TX and 16×8 RX FIFOs
.equ SPI0_BASE, (0x40080000)
.equ SPI0_XOR_BASE, (SPI0_BASE + XOR_OFFSET)
.equ SPI0_SET_BASE, (SPI0_BASE + SET_OFFSET)
.equ SPI0_CLR_BASE, (SPI0_BASE + CLR_OFFSET)
.equ SPI1_BASE, (0x40088000)
.equ SPI1_XOR_BASE, (SPI1_BASE + XOR_OFFSET)
.equ SPI1_SET_BASE, (SPI1_BASE + SET_OFFSET)
.equ SPI1_CLR_BASE, (SPI1_BASE + CLR_OFFSET)

.equ SPI_SSPCR0_OFFSET,        (0x000) // Control0
.equ SPI_SSPCR1_OFFSET,        (0x004) // Control1
.equ SPI_SSPDR_OFFSET,         (0x008) // Data
.equ SPI_SSPSR_OFFSET,         (0x00c) // Status 
.equ SPI_SSPCPSR_OFFSET,       (0x010) // Clock prescale
.equ SPI_SSPIMSC_OFFSET,       (0x014) // Interrupt mask set/clear
.equ SPI_SSPRIS_OFFSET,        (0x018) // Raw interrupt status
.equ SPI_SSPMIS_OFFSET,        (0x01c) // Masked interrupt status
.equ SPI_SSPICR_OFFSET,        (0x020) // Interrupt clear
.equ SPI_SSPDMACR_OFFSET,      (0x024) // DMA control

.equ SPI_SSPPERIPHID0_OFFSET,  (0xfe0) // Peripheral identification 0
.equ SPI_SSPPERIPHID1_OFFSET,  (0xfe4)  // 1
.equ SPI_SSPPERIPHID2_OFFSET,  (0xfe8)  // 2
.equ SPI_SSPPERIPHID3_OFFSET,  (0xfec)  // 3
.equ SPI_SSPPCELLID0_OFFSET,   (0xff0) // PrimeCell identification 0
.equ SPI_SSPPCELLID1_OFFSET,   (0xff4)  // 1
.equ SPI_SSPPCELLID2_OFFSET,   (0xff8)  // 2
.equ SPI_SSPPCELLID3_OFFSET,   (0xffc)  // 3

/* PIO */
.equ PIO0_BASE,                 (0x50200000)
.equ PIO1_BASE,                 (0x50300000)
.equ PIO2_BASE,                 (0x50400000)
.equ PIO0_SET_BASE,             (PIO0_BASE + SET_OFFSET)
.equ PIO1_SET_BASE,             (PIO1_BASE + SET_OFFSET)
.equ PIO2_SET_BASE,             (PIO2_BASE + SET_OFFSET)
.equ PIO0_CLR_BASE,             (PIO0_BASE + CLR_OFFSET)
.equ PIO1_CLR_BASE,             (PIO1_BASE + CLR_OFFSET)
.equ PIO2_CLR_BASE,             (PIO2_BASE + CLR_OFFSET)
.equ PIO0_XOR_BASE,             (PIO0_BASE + XOR_OFFSET)
.equ PIO1_XOR_BASE,             (PIO1_BASE + XOR_OFFSET)
.equ PIO2_XOR_BASE,             (PIO2_BASE + XOR_OFFSET)

.equ PIO_CTRL_OFFSET,           (0x000)
.equ PIO_FSTAT_OFFSET,          (0x004)
.equ PIO_FDEBUG_OFFSET,         (0x008)
.equ PIO_FLEVEL_OFFSET,         (0x00c)
.equ PIO_TXF0_OFFSET,           (0x010)
.equ PIO_TXF1_OFFSET,           (0x014)
.equ PIO_TXF2_OFFSET,           (0x018)
.equ PIO_TXF3_OFFSET,           (0x01c)
.equ PIO_RXF0_OFFSET,           (0x020)
.equ PIO_RXF1_OFFSET,           (0x024)
.equ PIO_RXF2_OFFSET,           (0x028)
.equ PIO_RXF3_OFFSET,           (0x02c)
.equ PIO_IRQ_OFFSET,            (0x030)
.equ PIO_IRQ_FORCE_OFFSET,      (0x034)
.equ PIO_INSTR_MEM0_OFFSET,     (0x048) // 32 instruction slots starting from this address
.equ PIO_SM0_CLKDIV_OFFSET,     (0x0c8)
.equ PIO_SM0_EXECCTRL_OFFSET,   (0x0cc)
.equ PIO_SM0_SHIFTCTRL_OFFSET,  (0x0d0)
.equ PIO_SM0_ADDR_OFFSET,       (0x0d4)
.equ PIO_SM0_INSTR_OFFSET,      (0x0d8)
.equ PIO_SM0_PINCTRL,           (0x0dc)

/*GPIO*/
.equ IO_BANK0_BASE, (0x40028000)
.equ IO_BANK0_XOR_BASE, (IO_BANK0_BASE + 0x1000)
.equ IO_BANK0_SET_BASE, (IO_BANK0_BASE + 0x2000)
.equ IO_BANK0_CLR_BASE, (IO_BANK0_BASE + 0x3000)

.equ GPIO0_CTRL_OFFSET, ((0x8 * 0x0) + 0x4)
.equ GPIO1_CTRL_OFFSET, ((0x8 * 0x1) + 0x4)
.equ GPIO2_CTRL_OFFSET, ((0x8 * 0x2) + 0x4)
.equ GPIO3_CTRL_OFFSET, ((0x8 * 0x3) + 0x4)
.equ GPIO4_CTRL_OFFSET, ((0x8 * 0x4) + 0x4)
.equ GPIO5_CTRL_OFFSET, ((0x8 * 0x5) + 0x4)
.equ GPIO6_CTRL_OFFSET, ((0x8 * 0x6) + 0x4)
.equ GPIO7_CTRL_OFFSET, ((0x8 * 0x7) + 0x4)
.equ GPIO16_CTRL_OFFSET, ((0x8 * 16) + 0x4)
.equ GPIO17_CTRL_OFFSET, ((0x8 * 17) + 0x4)
.equ GPIO18_CTRL_OFFSET, ((0x8 * 18) + 0x4)
.equ GPIO19_CTRL_OFFSET, ((0x8 * 19) + 0x4)
.equ GPIO25_CTRL_OFFSET, ((0x8 * 25) + 0x4) // This is the LED on sparkfun rp2350 board

.equ PADS_BANK0_BASE, 0x40038000

.equ PADS_BANK0_RW,    (PADS_BANK0_BASE + 0x0000)
.equ PADS_BANK0_XOR,   (PADS_BANK0_BASE + 0x1000)
.equ PADS_BANK0_SET,   (PADS_BANK0_BASE + 0x2000)
.equ PADS_BANK0_CLR,   (PADS_BANK0_BASE + 0x3000)
.equ PADS_BANK0_GPIO0_OFFSET, (0x4*(1+0)) // gpio0 actually starts at 0x4 instead of 0x0.
.equ PADS_BANK0_GPIO1_OFFSET, (0x4*(1+1))
.equ PADS_BANK0_GPIO2_OFFSET, (0x4*(1+2))
.equ PADS_BANK0_GPIO3_OFFSET, (0x4*(1+3))
.equ PADS_BANK0_GPIO4_OFFSET, (0x4*(1+4))
.equ PADS_BANK0_GPIO5_OFFSET, (0x4*(1+5))
.equ PADS_BANK0_GPIO6_OFFSET, (0x4*(1+6))
.equ PADS_BANK0_GPIO7_OFFSET, (0x4*(1+7))
.equ PADS_BANK0_GPIO16_OFFSET, (0x4*(1+16))
.equ PADS_BANK0_GPIO17_OFFSET, (0x4*(1+17))
.equ PADS_BANK0_GPIO18_OFFSET, (0x4*(1+18))
.equ PADS_BANK0_GPIO19_OFFSET, (0x4*(1+19))

/* DMA */
.equ DMA_BASE,                          (0x50000000)
.equ DMA_SET_BASE,                      (DMA_BASE + SET_OFFSET)
.equ DMA_CLR_BASE,                      (DMA_BASE + CLR_OFFSET)
.equ DMA_XOR_BASE,                      (DMA_BASE + XOR_OFFSET)
#define DMA_CH_READ_ADDR_OFFSET(channel)          (0x000 + channel*0x40)
#define DMA_CH_WRITE_ADDR_OFFSET(channel)         (0x004 + channel*0x40)
#define DMA_CH_TRANS_COUNT_OFFSET(channel)        (0x008 + channel*0x40)
#define DMA_CH_CTRL_TRIG_OFFSET(channel)          (0x00c + channel*0x40)
#define DMA_CH_AL1_READ_ADDR_OFFSET(channel)      (0x010 + channel*0x40)
#define DMA_CH_AL1_WRITE_ADDR_OFFSET(channel)     (0x014 + channel*0x40)
#define DMA_CH_AL1_TRANS_COUNT_OFFSET(channel)    (0x018 + channel*0x40)
#define DMA_CH_AL1_CTRL_TRIG_OFFSET(channel)      (0x01c + channel*0x40)
#define DMA_CH_AL2_READ_ADDR_OFFSET(channel)      (0x020 + channel*0x40)
#define DMA_CH_AL2_WRITE_ADDR_OFFSET(channel)     (0x024 + channel*0x40)
#define DMA_CH_AL2_TRANS_COUNT_OFFSET(channel)    (0x028 + channel*0x40)
#define DMA_CH_AL2_CTRL_TRIG_OFFSET(channel)      (0x02c + channel*0x40)
#define DMA_CH_AL3_READ_ADDR_OFFSET(channel)      (0x030 + channel*0x40)
#define DMA_CH_AL3_WRITE_ADDR_OFFSET(channel)     (0x034 + channel*0x40)
#define DMA_CH_AL3_TRANS_COUNT_OFFSET(channel)    (0x038 + channel*0x40)
#define DMA_CH_AL3_CTRL_TRIG_OFFSET(channel)      (0x03c + channel*0x40)

/* GPIO interrupt enable */
.equ IO_BANK0_INTE0, (IO_BANK0_BASE + 0x100)

/* Cortex M33 */
// IMPORTANT(gh) : M33 does not support CLR,XOR,SET(except some registers on EPPB)
.equ M33_BASE, (0xe0000000)

.equ M33_NVIC_ISER0_OFFSET, (0x0e100) // set interrupt enable
.equ M33_NVIC_ISER1_OFFSET, (0x0e104) // set interrupt enable

.equ M33_NVIC_ICER0_OFFSET, (0x0e180) // clear interrupt enable
.equ M33_NVIC_ICER1_OFFSET, (0x0e184) // clear interrupt enable

.equ M33_NVIC_ISPR0_OFFSET, (0x0e200) // set pending interrupt
.equ M33_NVIC_ISPR1_OFFSET, (0x0e204) // set pending interrupt

.equ M33_NVIC_ICPR0_OFFSET, (0x0e280) // clear pending interrupt
.equ M33_NVIC_ICPR1_OFFSET, (0x0e284) // clear pending interrupt

.equ M33_ICSR_OFFSET,       (0x0ed04)
.equ M33_VTOR_OFFSET,       (0x0ed08) // offset of the vector table base address from 0x00000000
.equ M33_AIRCR_OFFSET,      (0x0ed0c) // Use the Application Interrupt and Reset Control Register to: determine data endianness, clear all active state information from debug halt mode, request a system reset.

.equ M33_SHPR1_OFFSET,      (0x0ed18) // Sets or returns priority for system handlers 4 - 7

.equ M33_SHCSR_OFFSET,      (0x0ed24) // Provides access to the active and pending status of system exceptions
.equ M33_CFSR_OFFSET,       (0x0ed28) // Contains the three Configurable Fault Status Registers.
                                     // UFSR, BFSR, MMFSR
                                     
.equ M33_HFSR_OFFSET,       (0x0ed2c) // Shows the cause of any HardFaults

.equ M33_CPACR_OFFSET,      (0x0ed88)

// NOTE(gh) Once exiting from BootROM, SAU region 7 is enabled with
// a base address of 0x000046A0 and the end address of 0x00007FFF(end of BootROM)
.equ M33_SAU_CTRL_OFFSET,   (0x0edd0)
.equ M33_SAU_RNR_OFFSET,    (0x0edd8) // Selects the region currently accessed by SAU_RBAR and SAU_RLAR
.equ M33_SAU_RBAR_OFFSET,   (0x0eddc) // Provides indirect read and write access to the base address of the currently selected SAU region
.equ M33_SAU_RLAR_OFFSET,   (0x0ede0) // Provides indirect read and write access to the limit address of the currently selected SAU region
.equ M33_SFAR_OFFSET,       (0x0ede8) // Shows the address of the memory location that caused a Security violation

/*PIO*/
.equ PIO0_BASE, (0x50200000)
.equ PIO0_XOR_BASE, (PIO0_BASE + 0x1000)
.equ PIO0_SET_BASE, (PIO0_BASE + 0x2000)
.equ PIO0_CLR_BASE, (PIO0_BASE + 0x3000)

.equ PIO0_CTRL_OFFSET, (0x0)
.equ PIO0_FSTAT_OFFSET, (0x4)
.equ PIO0_FDEBUG_OFFSET, (0x8)
.equ PIO0_FLEVEL_OFFSET, (0xc)

.equ SM0_TXFIFO_OFFSET, (0x10)
.equ SM1_TXFIFO_OFFSET, (0x14)
.equ SM2_TXFIFO_OFFSET, (0x18)
.equ SM3_TXFIFO_OFFSET, (0x1c)
.equ SM0_RXFIFO_OFFSET, (0x20)
.equ SM1_RXFIFO_OFFSET, (0x24)
.equ SM2_RXFIFO_OFFSET, (0x28)
.equ SM3_RXFIFO_OFFSET, (0x2c)

.equ PIO0_IRQ_OFFSET, (0x30)
.equ PIO0_IRQ_FORCE_OFFSET, (0x34)
.equ PIO0_INPUT_SYNC_BYPASS_OFFSET, (0x38)
.equ PIO0_DBG_PADOUT_OFFSET, (0x3c)
.equ PIO0_DBG_PADOE_OFFSET, (0x40)
.equ PIO0_DBG_CFGINFO_OFFSET, (0x44)

// although each 'slot' is 4 bytes in the address space, each 'instruction' is 2 bytes
.equ PIO0_INSTR_MEM_START_OFFSET, (0x048)
.equ PIO0_INSTR_MEM_START, (PIO0_BASE + PIO0_INSTR_MEM_START_OFFSET) 
// user-defined PIO instruction location inside SRAM. At startup, debug probe should load & store the instructions
// from here to PIO0_INSTR_MEM_START
.equ PIO0_INSTR_MEM_SRARM_START, (0x20040000) // sram bank 4 for now 

.equ SM0_TXF, (PIO0_BASE + 0x10)
.equ SM1_TXF, (PIO0_BASE + 0x14)
.equ SM2_TXF, (PIO0_BASE + 0x18)
.equ SM3_TXF, (PIO0_BASE + 0x1c)

.equ SM0_RXF, (PIO0_BASE + 0x20)
.equ SM1_RXF, (PIO0_BASE + 0x24)
.equ SM2_RXF, (PIO0_BASE + 0x28)
.equ SM3_RXF, (PIO0_BASE + 0x2c)

.equ SM0_BASE, (PIO0_BASE + 0x0c8)
.equ SM0_XOR_BASE, (SM0_BASE + 0x1000) 
.equ SM0_SET_BASE, (SM0_BASE + 0x2000) 
.equ SM0_CLR_BASE, (SM0_BASE + 0x3000) 

.equ SM1_BASE, (PIO0_BASE + 0x0e0) 
.equ SM1_XOR_BASE, (SM1_BASE + 0x1000) 
.equ SM1_SET_BASE, (SM1_BASE + 0x2000) 
.equ SM1_CLR_BASE, (SM1_BASE + 0x3000) 

.equ SM_CLKDIV_OFFSET, (0x0) 
.equ SM_EXECCTRL_OFFSET, (0x4) 
.equ SM_SHIFTCTRL_OFFSET, (0x8) // out/in shift registers control
.equ SM_ADDR_OFFSET, (0xc) // RO
.equ SM_INSTR_OFFSET, (0x10) // write to change the SM's
.equ SM_PINCTRL_OFFSET, (0x14)

.equ SM_PINCTRL_OUT_BASE_SHIFT, 0
.equ SM_PINCTRL_SET_BASE_SHIFT, 5
.equ SM_PINCTRL_SIDESET_BASE_SHIFT, 10
.equ SM_PINCTRL_IN_BASE_SHIFT, 15
.equ SM_PINCTRL_OUT_COUNT_SHIFT, 20
.equ SM_PINCTRL_SET_COUNT_SHIFT, 26
.equ SM_PINCTRL_SIDESET_COUNT_SHIFT, 29

.equ SM_SHIFTCTRL_AUTOPUSH_SHIFT, 16
.equ SM_SHIFTCTRL_AUTOPULL_SHIFT, 17
.equ SM_SHIFTCTRL_IN_SHIFTDIR_SHIFT, 18
.equ SM_SHIFTCTRL_OUT_SHIFTDIR_SHIFT, 19
.equ SM_SHIFTCTRL_PUSH_THRESH_SHIFT, 20
.equ SM_SHIFTCTRL_PULL_THRESH_SHIFT, 25
.equ SM_SHIFTCTRL_FJOIN_TX_SHIFT, 30
.equ SM_SHIFTCTRL_FJOIN_RX_SHIFT, 31

















