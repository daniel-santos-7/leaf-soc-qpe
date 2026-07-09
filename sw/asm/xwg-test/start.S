.equ RAM_TOP, 0x80008000

.include "../common/qp.inc"

.section .text
.globl _start

_start:
    li sp, RAM_TOP

    # Load all register values first
    li s0, 0x1999999A   # FTW = 10 MHz
    li s1, 0x40000000   # POW = quarter-cycle phase
    li s2, 0x000007FF   # AMP = 2047
    li s3, 0x00001999   # DRAG = 0.2
    li s4, 0x0147AE14   # ENV = 200 cyc (4 us)
    li s5, 0x0000000A   # DELAY = 10 cycles
    
    # Write all WGEN registers
    qp.ftw  s0
    qp.pow  s1
    qp.amp  s2
    qp.drag s3
    qp.env  s4
    qp.delay s5
    qp.trigger
    qp.wait

2:  wfi
    j 2b
