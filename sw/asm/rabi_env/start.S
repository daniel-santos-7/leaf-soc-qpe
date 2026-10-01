# rabi_env: Envelope duration sweep, no UART
# Sweeps ENV (envelope step) from slow to fast.
# Fixed amplitude at half scale.

.equ RAM_TOP,  0x80008000

.equ FTW_PI,   0x1999999A
.equ ENV_START, 0x00100000
.equ ENV_END,   0x01000000
.equ ENV_STEP,  0x00100000
.equ AMP_HALF,  2048
.equ DRAG_ZERO, 0
.equ REPEAT,    3

.include "../common/qp.inc"

.section .text
.globl _start

_start:
    li   sp, RAM_TOP

    qp.ftw   9
    qp.pow   0
    qp.amp   18
    qp.drag  0
    qp.env   19
    qp.delay 0

    li   s1, FTW_PI
    li   s3, ENV_START
    li   s2, AMP_HALF

    li   s4, REPEAT
    li   s5, ENV_STEP

repeat_loop:
    beqz s4, done
    li   s3, ENV_START

pulse_loop:
    qp.wait
    qp.trigger

    add  s3, s3, s5
    li   t0, ENV_END
    ble  s3, t0, pulse_loop

    addi s4, s4, -1
    j    repeat_loop

done:
    wfi
    j    done
