.equ RAM_TOP, 0x80008000

.include "../common/wgen.inc"

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

    wgen.ftw   s0
    wgen.pow   s1
    wgen.amp   s2
    wgen.drag  s3
    wgen.env   s4
    wgen.delay s5
    wgen.trigger
    wgen.wait

2:  wfi
    j 2b
