// SoC memory map
.equ ROM_BASE,      0x00001000
.equ UART_BASE,     0x10000000
.equ IO1_BASE,      0x10001000
.equ XIP_BASE,      0x20000000
.equ RAM_BASE,      0x80000000

// Memory sizes
.equ ROM_SIZE,      0x200
.equ RAM_SIZE,      0x10000      // 64 KB
.equ XIP_SIZE,      0x1000000    // 16 MB

// UART register offsets
.equ UART_STAT,     0x00
.equ UART_CTRL,     0x04
.equ UART_BRDV,     0x08
.equ UART_DATA,     0x0C

// Wave generator (MMIO via IO1)
.equ WGEN_BASE,     0x10001000
.equ WGEN_FTW,      0x00
.equ WGEN_POW,      0x04
.equ WGEN_AMP,      0x08
.equ WGEN_ENV,      0x0C
.equ WGEN_DRAG,     0x10
.equ WGEN_DELAY,    0x14
.equ WGEN_TRIG,     0x18


