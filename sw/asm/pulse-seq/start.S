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

.include "../common/qpn.inc"

.section .text
.globl _start

_start:
    li sp, RAM_TOP

    li s0, 0x0000000F
    li s1, 0x000000FF
    li s2, 0x00000FFF
    li s3, 0x0000FFFF
    li s4, 0x000FFFFF
    li s5, 0x00FFFFFF

    # Fire pi-pulse
    qp.ftw   s0
    qp.pow   s1
    qp.amp   s2
    qp.drag  s3
    qp.env   s4
    qp.delay s5
    qp.trigger

    # Halt
1:  j 1b
