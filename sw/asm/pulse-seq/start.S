// pulse-seq: Autonomous microwave pulse sequence generator
// Clock: 50 MHz (20 ns/cycle)
// Repeats: π-pulse → π/2-pulse → Readout pulse → ...
// UART TX-only: no blocking on RX (safe for simulation)

.equ UART_BASE_ADDR, 0x10000000

.equ RAM_TOP,        0x80010000

// π-pulse: FTW=5 MHz, AMP=2047, ENV=200 cyc (4 µs), DRAG=0.2
.equ FTW_PI,         0x1999999A
.equ AMP_PI,         0x000007FF
.equ ENV_PI,         0x0147AE14
.equ DRAG_PI,        0x00001999

// π/2-pulse: AMP=1024 (half), ENV=100 cyc (2 µs)
.equ AMP_PI2,        0x00000400
.equ ENV_PI2,        0x028F5C29

// Readout pulse: FTW=10 MHz, AMP=3072, ENV=500 cyc (10 µs)
.equ FTW_READOUT,    0x33333333
.equ AMP_READOUT,    0x00000C00
.equ ENV_READOUT,    0x0083126F

.include "../common/xwg.inc"

.section .text
.globl _start

_start:
    li sp, RAM_TOP
    la a0, banner_str
    call uart_print_str

    li s0, FTW_PI
    li s1, DRAG_PI
    li s2, AMP_PI
    li s3, ENV_PI
    li s4, AMP_PI2
    li s5, ENV_PI2
    li s6, FTW_READOUT
    li s7, AMP_READOUT
    li s8, ENV_READOUT

loop:
    // π-pulse
    xwg.ftw s0
    xwg.pow x0
    xwg.amp s2
    xwg.env s3
    xwg.drag s1
    xwg.delay x0
    xwg.trigger
    call wait_ready
#    la a0, dot_str
#    call uart_print_str

    // π/2-pulse
    xwg.ftw s0
    xwg.pow x0
    xwg.amp s4
    xwg.env s5
    xwg.drag s1
    xwg.delay x0
    xwg.trigger
    call wait_ready
#    la a0, dot_str
#    call uart_print_str

    // Readout pulse
    xwg.ftw s6
    xwg.pow x0
    xwg.amp s7
    xwg.env s8
    xwg.drag x0
    xwg.delay x0
    xwg.trigger
    call wait_ready
#    la a0, dot_str
#    call uart_print_str

    j loop

wait_ready:
    csrr t0, WGEN_CSR_TRIG
    andi t0, t0, 2
    beqz t0, wait_ready
    ret

uart_write:
    li  t1, UART_BASE_ADDR
1:
    lbu t0, 0x0(t1)
    andi t0, t0, 0x20
    beqz t0, 1b
    andi a0, a0, 0xFF
    sb   a0, 0xC(t1)
    ret

uart_print_str:
    addi sp, sp, -4
    sw   ra, 0(sp)
    mv   t2, a0
1:
    lbu  t0, 0(t2)
    beqz t0, 2f
    mv   a0, t0
    addi sp, sp, -4
    sw   t2, 0(sp)
    call uart_write
    lw   t2, 0(sp)
    addi sp, sp, 4
    addi t2, t2, 1
    j    1b
2:
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

banner_str:
    .asciz "pulse-seq\n"
dot_str:
    .asciz "."
