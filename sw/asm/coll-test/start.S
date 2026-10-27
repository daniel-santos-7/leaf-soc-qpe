.globl _start
_start:
    li t0, 0x80000000
    li t1, 0
loop:
    addi t1, t1, 1
    sw t1, 0(t0)
    j loop
