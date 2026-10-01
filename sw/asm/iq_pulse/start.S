.equ RAM_SIZE, 0x8000
.equ RAM_BASE, 0x80000000
.equ RAM_TOP,  RAM_BASE + RAM_SIZE

.include "../common/qp.inc"

.section .text
.globl _start

_start:
    li sp, RAM_TOP

    qp.ftw   8
    qp.pow   0
    qp.amp   18
    qp.drag  20
    qp.env   19
    qp.delay 21

    li s0, 0x028F5C28    # FTW ~1 MHz
    li s2, 0x0000FFFF    # AMP max
    li s4, 0x00001999    # DRAG = 0.1
    li s3, 0x000346DC    # ENV ~200 µs (214748)
    li s5, 0x0000C350    # DELAY = 50000 (~500 µs gap após pulso)

loop:
    qp.trigger
    qp.wait
    j loop
