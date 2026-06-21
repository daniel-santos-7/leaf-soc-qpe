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

    # Bank 0: pi-pulse
    xwg.ftw   0, s0
    xwg.pow   0, x0
    slli t0, s1, 16
    or   t0, t0, s2
    xwg.amp   0, t0
    xwg.env   0, s3
    xwg.delay 0, x0

    # Bank 1: pi/2-pulse
    xwg.ftw   1, s0
    slli t0, s1, 16
    or   t0, t0, s4
    xwg.amp   1, t0
    xwg.env   1, s5
    xwg.delay 1, x0

    # Bank 2: readout
    xwg.ftw   2, s6
    xwg.amp   2, s7       # DRAG=0, combined=AMP
    xwg.env   2, s8
    xwg.delay 2, x0

    xwg.start 3

    # Halt
2:  j 2b
