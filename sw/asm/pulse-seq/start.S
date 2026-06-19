# pulse-seq: three-pulse sequence (pi, pi/2, readout), one shot
.equ UART_BASE_ADDR, 0x10000000
.equ RAM_TOP,        0x80010000

# pi-pulse: FTW=5 MHz, AMP=2047, ENV=200 cyc (4 us), DRAG=0.2
.equ FTW_PI,         0x1999999A
.equ AMP_PI,         0x000007FF
.equ ENV_PI,         0x0147AE14
.equ DRAG_PI,        0x00001999

# pi/2-pulse: AMP=1024, ENV=100 cyc (2 us)
.equ AMP_PI2,        0x00000400
.equ ENV_PI2,        0x028F5C29

# Readout: FTW=10 MHz, AMP=3072, ENV=500 cyc (10 us)
.equ FTW_READOUT,    0x33333333
.equ AMP_READOUT,    0x00000C00
.equ ENV_READOUT,    0x0083126F

.include "../common/xwg.inc"

.section .text
.globl _start

_start:
    li sp, RAM_TOP

    li s0, FTW_PI
    li s1, DRAG_PI
    li s2, AMP_PI
    li s3, ENV_PI
    li s4, AMP_PI2
    li s5, ENV_PI2
    li s6, FTW_READOUT
    li s7, AMP_READOUT
    li s8, ENV_READOUT

    # Entry 0: pi-pulse
    xwg.ftw      s0
    xwg.pow      x0
    xwg.amp_drag s2, s1
    xwg.env      s3
    xwg.delay    x0
    xwg.push

    # Entry 1: pi/2-pulse
    xwg.ftw      s0
    xwg.amp_drag s4, s1
    xwg.env      s5
    xwg.push

    # Entry 2: readout
    xwg.ftw      s6
    xwg.amp_drag s7, x0
    xwg.env      s8
    xwg.push_start

1:  xwg.trig t0
    andi t0, t0, 2
    beqz t0, 1b

    # Halt
2:  j 2b
