.equ UART_BASE_ADDR, 0x10000000

.globl _start
_start:
.rept 237
    nop
.endr
    la a0, ok_str
    call uart_print_str
inf:
    wfi
    j inf

uart_print_str:
    lbu t0, 0(a0)
    beqz t0, 1f
    mv a1, t0
    call uart_write
    addi a0, a0, 1
    j uart_print_str
1:
    ret

uart_write:
    li  t1, UART_BASE_ADDR
1:
    lbu t0, 0x0(t1)
    andi t0, t0, 0x20
    beqz t0, 1b
    andi a1, a1, 0xFF
    sb   a1, 0xC(t1)
    ret

ok_str:
    .asciz "OK\n"