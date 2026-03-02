.equ UART_BASE_ADDR, 0x10000000

.globl _start
_start:
    li a0, 'H'
    call uart_write
    li a0, 'i'
    call uart_write
    li a0, '!'
    call uart_write
    j _start

uart_write:
    li  t1, UART_BASE_ADDR     # load UART base address
1:
    lbu t0, 0x0(t1)            # read UART status register
    andi t0, t0, 0x20          # mask TX ready flag (bit 5)
    beqz t0, 1b                # wait until TX is ready
    andi a0, a0, 0xFF          # ensure only 8 bits are written
    sb   a0, 0xC(t1)           # write byte to TX register
    ret                        # return to caller
