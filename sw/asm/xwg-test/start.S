.equ RAM_TOP, 0x80010000

.include "../common/qpn.inc"

.section .text
.globl _start

_start:
    li sp, RAM_TOP

    # Single pulse exercising all registers
    li s0, 0x1999999A   # FTW = 5 MHz
    qp.ftw  s0
    li s0, 0x40000000   # POW = quarter-cycle phase
    qp.pow  s0
    li s0, 0x000007FF   # AMP = 2047
    qp.amp  s0
    li s0, 0x00001999   # DRAG = 0.2
    qp.drag s0
    li s0, 0x0147AE14   # ENV = 200 cyc (4 us)
    qp.env  s0
    li s0, 0x0000000A   # DELAY = 10 cycles
    qp.delay s0
    qp.trigger

1:  csrr t0, WG_TRIG
    andi t0, t0, 1
    bnez t0, 1b

2:  wfi
    j 2b
