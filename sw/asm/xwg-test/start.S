.equ RAM_TOP, 0x80010000

.include "../common/xwg.inc"

.section .text
.globl _start

_start:
    li sp, RAM_TOP

    # Entry 1
    li s0, 0x00002D79   # FTW (1MHz)
    li s1, 0x00000000   # POW
    li s3, 0x000007FF   # AMP (DRAG=0)
    li s4, 0x01000000   # ENV
    li s5, 0x00000000   # DELAY
    
    xwg.ftw      s0
    xwg.pow      s1
    xwg.amp_drag s3
    xwg.env      s4
    xwg.delay    s5
    xwg.push

    # Entry 2
    li s0, 0x00002D79   # FTW (1MHz)
    li s1, 0x80000000   
    li s3, 0x000007FF   # AMP (DRAG=0)
    li s4, 0x02000000
    li s5, 0x0000000A
    
    xwg.ftw      s0
    xwg.pow      s1
    xwg.amp_drag s3
    xwg.env      s4
    xwg.delay    s5
    xwg.push

    xwg.start

1:  wfi
    j 1b
