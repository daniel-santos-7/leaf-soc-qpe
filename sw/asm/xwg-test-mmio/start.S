.equ RAM_TOP, 0x80008000

.include "../common/qpe_mmio.inc"

.section .text
.globl _start

_start:
    li sp, RAM_TOP

    li s0, 0x1999999A
    li s1, 0x40000000
    li s2, 0x000007FF
    li s3, 0x00001999
    li s4, 0x0147AE14
    li s5, 0x0000000A

    qpe_mmio.ftw   s0
    qpe_mmio.pow   s1
    qpe_mmio.amp   s2
    qpe_mmio.drag  s3
    qpe_mmio.env   s4
    qpe_mmio.delay s5
    qpe_mmio.trigger
    qpe_mmio.wait

2:  wfi
    j 2b
