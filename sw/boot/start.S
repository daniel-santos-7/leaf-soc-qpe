.equ UART_BRDV, 0x28B0

.equ RAM_BASE_ADDR, 0x80000000
.equ RAM_SIZE, 0x10000

.equ RAM_JUMP_CMD, 0x4A
.equ RAM_LOAD_CMD, 0x4C

.equ ACK, 0x06
.equ NAK, 0x15
.equ CAN, 0x18

.text
.globl _start
_start:
    li a0, UART_BRDV
    call uart_set_baud

read_command:
    call uart_read
    li t0, RAM_LOAD_CMD
    beq t0, a0, ram_load_command
    li t0, RAM_JUMP_CMD
    beq t0, a0, ram_jump_command
    li a0, NAK
    call uart_write
    j read_command

ram_load_command:
    li a0, ACK
    call uart_write

read_program_size:
    li s0, RAM_BASE_ADDR
    li s1, RAM_BASE_ADDR + 0x4
    li s2, 0x0
    la s3, read_program_size
    la s4, read_program_block
    j read_data

read_program_block:
    li s0, RAM_BASE_ADDR
    li s1, RAM_BASE_ADDR
    li s2, 0x0
    la s3, 2f
    la s4, 3f
    lw s5, 0x0(s0)
    mv s6, s5
    andi s5, s5, -0x400
1:
    addi s1, s1, 0x400
    j read_data
2:
    addi s0, s0, -0x400
    li s2, 0x0
    j read_data
3:
    bne s0, s5, 1b
    j read_program_remainder

read_program_remainder:
    mv s0, s5
    mv s1, s6
    li s2, 0x0
    la s3, read_program_remainder
    la s4, read_command
    j read_data

# s0: start address
# s1: end address
# s2: CRC seed
# s3: return pointer (NAK)
# s4: return pointer (ACK)
read_data:
1:
    call uart_read
    sb a0, 0x0(s0)
    mv a1, s2
    call crc8_update
    mv s2, a0
    addi s0, s0, 0x1
    bne s0, s1, 1b
2:
    call uart_read
    beq a0, s2, 3f
    li a0, NAK
    call uart_write
    jr s3
3:
    li a0, ACK
    call uart_write
    jr s4

ram_jump_command:
	li a0, ACK
    call uart_write
    li t0, RAM_BASE_ADDR
    jr t0
