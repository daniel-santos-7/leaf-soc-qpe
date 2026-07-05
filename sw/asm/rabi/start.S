# rabi: Amplitude sweep, bank 0 loop, no UART

.equ RAM_TOP,  0x80010000

.equ FTW_PI,   0x1999999A
.equ ENV_PI,   0x0147AE14
.equ DRAG_PI,  0x00001999
.equ AMP_STEP, 41
.equ AMP_MAX,  4095
.equ REPEAT,   3

.include "../common/qpn.inc"

.section .text
.globl _start

_start:
    li   sp, RAM_TOP

    li   s1, FTW_PI
    li   s2, ENV_PI
    li   s3, DRAG_PI

    qp.ftw  s1
    qp.pow  x0
    qp.drag s3
    qp.env  s2
    qp.delay x0

    li   s4, REPEAT

repeat_loop:
    beqz s4, done
    li   a0, 0

pulse_loop:
    qp.amp  a0
    qp.trigger

1:  csrr t0, WG_TRIG
    andi t0, t0, 1
    bnez t0, 1b

    addi a0, a0, AMP_STEP
    li   t0, AMP_MAX
    ble  a0, t0, pulse_loop

    addi s4, s4, -1
    j    repeat_loop

done:
    wfi
    j    done
