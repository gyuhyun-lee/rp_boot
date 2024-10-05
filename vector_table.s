.syntax unified
.cpu cortex-m33
.thumb
    // [2] p.317 to see all the offsets of the exceptions
    .word 0x20020000 // Initial stack pointer
    .word (_start + 1) // start address for the reset handler, bit 0 indicates 'thumb mode'
    // NOTE(gh) Since we aren't enabling the faults other than the hard fault(enabled by default)
    // all of these faults will get escalated into hard fault
    .word (NMI_fault_handler + 1) 
    .word (hard_fault_handler + 1) // hard fault
    .word (memmanage_fault_handler + 1)
    .word (bus_fault_handler + 1)
    .word (usage_fault_handler + 1)
    .word (secure_fault_handler + 1)
    .word 0x0 // not used by m33
    .word 0x0 // not used by m33
    .word 0x0 // not used by m33
    .word 0x0 // (svc_vector + 1) // svc = supervisor call
    .word 0x0 // (debug_monitor_vector + 1)  // TODO(gh) debug_monitor_vector?
    .word 0x0 // not used by m33
    .word 0x0 // (pendsv_vector + 1) // TODO(gh) pendsv?
    .word 0x0 // (systick_vector + 1) // TODO(gh) systick timer?


    // [1] section 3.2 to see all the interrupts
    .word 0x0 // 00
    .word 0x0 // 01
    .word 0x0 // 02
    .word 0x0 // 03
    .word 0x0 // 04
    .word 0x0 // 05
    .word 0x0 // 06
    .word 0x0 // 07
    .word 0x0 // 08
    .word 0x0 // 09
    .word 0x0 // 10
    .word 0x0 // 11
    .word 0x0 // 12
    .word 0x0 // 13
    .word 0x0 // 14
    .word 0x0 // 15

    .word 0x0 // 16
    .word 0x0 // 17
    .word 0x0 // 18
    .word 0x0 // 19
    .word 0x0 // 20
    .word 0x0 // 21
    .word 0x0 // 22
    .word 0x0 // 23
    .word 0x0 // 24
    .word 0x0 // 25
    .word 0x0 // 26
    .word 0x0 // 27
    .word 0x0 // 28
    .word 0x0 // 29
    .word 0x0 // 30
    .word 0x0 // 31

    .word 0x0 // 32
    .word (uart0_interrupt_handler+1) // 33
    .word 0x0 // 34
    .word 0x0 // 35
    .word 0x0 // 36
    .word 0x0 // 37
    .word 0x0 // 38
    .word 0x0 // 39

