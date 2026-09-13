# ramsey: Two-pulse Ramsey sequence using WGEN DELAY
# Fixed amplitude at half scale, sweeps inter-pulse delay.
# Needs ~500k cycles per sweep at max delay.

.equ RAM_TOP,  0x80008000

.equ FTW_PI,   0x1999999A
.equ ENV_PI,   0x0147AE14
.equ DRAG_ZERO, 0
.equ AMP_HALF,  2048
.equ DELAY_START, 0
.equ DELAY_STEP,  0x00000800
.equ DELAY_END,   0x00002800
.equ REPEAT,      1

.include "../common/qp.inc"

.section .text
.globl _start

_start:
    li   sp, RAM_TOP

    li   s1, FTW_PI
    li   s2, ENV_PI
    li   a0, AMP_HALF

    qp.ftw  s1
    qp.pow  x0
    qp.amp  a0
    qp.drag x0
    qp.env  s2

    li   s4, REPEAT
    li   s5, DELAY_STEP
    li   s6, DELAY_END

repeat_loop:
    beqz s4, done
    li   s3, DELAY_START
    qp.delay s3
    qp.trigger           # fire pulse1[n] — gerador ocioso, dispara imediato

delay_loop:
    qp.trigger           # enqueue pulse2[n] — gerador ocupado, enfileira
    qp.wait              # aguarda pulse1[n] + pulse2[n] completarem

    add  s3, s3, s5
    ble  s3, s6, enqueue_next
    addi s4, s4, -1
    j    repeat_loop

enqueue_next:
    qp.delay s3
    qp.trigger           # fire pulse1[n+1] — gerador ocioso, dispara imediato
    j delay_loop

done:
    wfi
    j    done
