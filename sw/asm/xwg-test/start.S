.equ RAM_TOP, 0x80010000

.include "../common/qpn.inc"

.section .text
.globl _start

_start:
    li sp, RAM_TOP

    # π-pulse
    li s0, 0x00002D79   # FTW (1MHz)
    qp.ftw  s0
    li s0, 0x00000000   # POW
    qp.pow  s0
    li s0, 0x000007FF   # AMP
    qp.amp  s0
    qp.drag x0
    li s0, 0x01000000   # ENV
    qp.env  s0
    li s0, 0x00000000   # DELAY
    qp.delay s0
    qp.trigger
1:  csrr t0, WG_TRIG
    andi t0, t0, 1
    bnez t0, 1b

    # π/2-pulse
    li s0, 0x00002D79   # FTW
    qp.ftw  s0
    li s0, 0x80000000   # POW
    qp.pow  s0
    li s0, 0x000003FF   # AMP
    qp.amp  s0
    qp.drag x0
    li s0, 0x02000000   # ENV
    qp.env  s0
    li s0, 0x0000000A   # DELAY
    qp.delay s0
    qp.trigger
2:  csrr t0, WG_TRIG
    andi t0, t0, 1
    bnez t0, 2b

3:  wfi
    j 3b
