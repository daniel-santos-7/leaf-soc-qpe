.equ UART_BASE_ADDR, 0x10000000

.section .text
.globl uart_set_baud
.globl uart_read
.globl uart_write

# --------------------------------------------------
# uart_set_baud
# Input:
#   a0 = baud rate divisor value
# Output:
#   none
# --------------------------------------------------
uart_set_baud:
    li t1, UART_BASE_ADDR       # load UART base address
    sh a0, 0x8(t1)              # write baud rate divisor
    ret

# --------------------------------------------------
# uart_read
# Blocking UART receive routine.
# Input:
#   none
# Output:
#   a0 = received byte (8-bit, zero-extended).
# --------------------------------------------------
uart_read:
    li t1, UART_BASE_ADDR      # load UART base address
1:
    lbu t0, 0x0(t1)            # read UART status register
    andi t0, t0, 0x4           # mask RX ready flag (bit 2)
    beqz t0, 1b                # loop until RX ready flag is set
    lbu a0, 0xC(t1)            # read received byte from RX register
    ret                        # return to caller

# --------------------------------------------------
# uart_write
# Blocking UART transmit routine.
# Input:
#   a0 = byte to transmit (only lower 8 bits are used)
# Output:
#   none
# --------------------------------------------------
uart_write:
    li  t1, UART_BASE_ADDR     # load UART base address
1:
    lbu t0, 0x0(t1)            # read UART status register
    andi t0, t0, 0x20          # mask TX ready flag (bit 5)
    beqz t0, 1b                # wait until TX is ready
    andi a0, a0, 0xFF          # ensure only 8 bits are written
    sb   a0, 0xC(t1)           # write byte to TX register
    ret                        # return to caller
