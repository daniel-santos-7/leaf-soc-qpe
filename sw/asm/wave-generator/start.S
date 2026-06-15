.equ UART_BASE_ADDR, 0x10000000
.equ WGEN_INCREMENT, 0x051EB852
.include "../common/xwgen.S"

.globl _start
_start:
    li t0, WGEN_INCREMENT
    li t1, 0
    li t2, 2047
    xwg.setup t0, t1, t2
    li a0, 'O'
    call uart_write
    li a0, 'K'
    call uart_write
    li a0, '\n'
    call uart_write
1:
    j 1b

uart_write:
    li  t1, UART_BASE_ADDR
1:
    lbu t0, 0x0(t1)
    andi t0, t0, 0x20
    beqz t0, 1b
    andi a0, a0, 0xFF
    sb   a0, 0xC(t1)
    ret
