.equ UART_BASE_ADDR, 0x10000000
.equ WGEN_CSR_INC,  0x7C0
.equ WGEN_CSR_PHA,  0x7C1
.equ WGEN_CSR_AMP,  0x7C2
.equ WGEN_CSR_CTRL, 0x7C3
.equ WGEN_INCREMENT, 0x051EB852

.globl _start
_start:
    li t0, WGEN_INCREMENT
    csrw WGEN_CSR_INC, t0
    li t0, 0
    csrw WGEN_CSR_PHA, t0
    li t0, 2047
    csrw WGEN_CSR_AMP, t0
    li t0, 1
    csrw WGEN_CSR_CTRL, t0
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
