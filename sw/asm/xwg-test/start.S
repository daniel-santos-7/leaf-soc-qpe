.equ RAM_TOP, 0x80010000

.include "../common/xwg.inc"

.section .text
.globl _start

_start:
    li sp, RAM_TOP

    # Entry 1
    li s0, 0x19999999   # FTW
    li s1, 0x10000000   # POW
    li s2, 0x00001999   # DRAG
    li s3, 0x000007FF   # AMP
    li s4, 0x0147AE14   # ENV
    li s5, 0x00000000   # DELAY
    
    xwg.ftw      s0
    xwg.pow      s1
    xwg.amp_drag s3, s2
    xwg.env      s4
    xwg.delay    s5
    xwg.push

    # Entry 2
    li s0, 0x10000000
    li s1, 0x00100000
    li s2, 0x00001000
    li s3, 0x000003FF
    li s4, 0x00100000
    li s5, 0x0000000A
    
    xwg.ftw      s0
    xwg.pow      s1
    xwg.amp_drag s3, s2
    xwg.env      s4
    xwg.delay    s5
    xwg.push

    xwg.start

1:  wfi
    j 1b
