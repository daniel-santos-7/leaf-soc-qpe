// SoC memory map
.equ ROM_BASE,      0x00001000
.equ UART_BASE,     0x10000000
.equ IO1_BASE,      0x10001000
.equ XIP_BASE,      0x20000000
.equ RAM0_BASE,     0x80000000
.equ RAM1_BASE,     0x90000000

// Memory sizes
.equ ROM_SIZE,      0x200
.equ RAM0_SIZE,     0x8000       // 32 KB
.equ RAM1_SIZE,     0x400        // 1 KB
.equ XIP_SIZE,      0x1000000    // 16 MB

// UART register offsets
.equ UART_STAT,     0x00
.equ UART_CTRL,     0x04
.equ UART_BRDV,     0x08
.equ UART_DATA,     0x0C



