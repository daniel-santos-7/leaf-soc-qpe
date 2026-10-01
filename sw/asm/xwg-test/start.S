.equ RAM_TOP, 0x80008000

.include "../common/qpe.inc"

.section .text
.globl _start

_start:
    li sp, RAM_TOP

    qpe.ftw   8
    qpe.pow   9
    qpe.amp   18
    qpe.drag  19
    qpe.env   20
    qpe.delay 21

    li s0, 0x1999999A   # FTW = 10 MHz
    li s1, 0x40000000   # POW = quarter-cycle phase
    li s2, 0x000007FF   # AMP = 2047
    li s3, 0x00001999   # DRAG = 0.2
    li s4, 0x0147AE14   # ENV = 200 cyc (4 us)
    li s5, 0x0000000A   # DELAY = 10 cycles
    qpe.trigger
    qpe.wait

2:  wfi
    j 2b
