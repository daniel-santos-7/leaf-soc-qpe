# rabi: Amplitude sweep, bank 0 loop, no UART

.equ RAM_TOP,  0x80008000

.equ FTW_PI,   0x1999999A
.equ ENV_PI,   0x0147AE14
.equ DRAG_PI,  0x00000000
.equ AMP_STEP, 41
.equ AMP_MAX,  4095
.equ REPEAT,   1

.include "../common/qpe.inc"

.section .text
.globl _start

_start:
    li   sp, RAM_TOP

    qpe.ftw   9
    qpe.pow   0
    qpe.amp   10
    qpe.drag  19
    qpe.env   18
    qpe.delay 0

    li   s1, FTW_PI
    li   s2, ENV_PI
    li   s3, DRAG_PI

    li   s4, REPEAT

repeat_loop:
    beqz s4, done
    li   a0, 0

pulse_loop:
    qpe.wait
    qpe.trigger

    addi a0, a0, AMP_STEP
    li   t0, AMP_MAX
    ble  a0, t0, pulse_loop

    li   a0, 0
    addi s4, s4, -1
    j    repeat_loop

done:
    wfi
    j    done
