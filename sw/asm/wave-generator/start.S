.equ UART_BASE_ADDR, 0x10000000
.equ WGEN_BASE_ADDR, 0x10001000
.equ WGEN_INCREMENT, 0x051EB852

.globl _start
_start:
    li t0, WGEN_INCREMENT
    li t1, WGEN_BASE_ADDR
    sw t0, 0x0(t1)
    li a0, 'O'
    call uart_write
    li a0, 'K'
    call uart_write
1:
    j 1b

uart_write:
    li  t1, UART_BASE_ADDR     # load UART base address
1:
    lbu t0, 0x0(t1)            # read UART status register
    andi t0, t0, 0x20          # mask TX ready flag (bit 5)
    beqz t0, 1b                # wait until TX is ready
    andi a0, a0, 0xFF          # ensure only 8 bits are written
    sb   a0, 0xC(t1)           # write byte to TX register
    ret                        # return to caller
