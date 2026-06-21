.equ RAM_TOP, 0x80010000

.include "../common/xwg.inc"

.section .text
.globl _start

_start:
    li sp, RAM_TOP

    # Bank 0: π-pulse
    li s0, 0x00002D79   # FTW (1MHz)
    xwg.ftw 0, s0
    li s0, 0x00000000   # POW
    xwg.pow 0, s0
    li s0, 0x000007FF   # AMP = {DRAG=0, AMP=0x7FF}
    xwg.amp 0, s0
    li s0, 0x01000000   # ENV
    xwg.env 0, s0
    li s0, 0x00000000   # DEL
    xwg.delay 0, s0

    # Bank 1: π/2-pulse
    li s0, 0x00002D79   # FTW
    xwg.ftw 1, s0
    li s0, 0x80000000   # POW
    xwg.pow 1, s0
    li s0, 0x000003FF   # AMP = {DRAG=0, AMP=0x3FF}
    xwg.amp 1, s0
    li s0, 0x02000000   # ENV
    xwg.env 1, s0
    li s0, 0x0000000A   # DEL
    xwg.delay 1, s0

    # Play both banks
    xwg.start 2

1:  wfi
    j 1b
