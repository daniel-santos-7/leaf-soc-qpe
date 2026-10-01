.equ RAM_TOP,        0x80008000
.equ UART_BASE_ADDR, 0x10000000

.include "../common/gpio.inc"

.section .text
.globl _start

_start:
    li   sp, RAM_TOP
    li   s1, 0

    li   s0, 0x0F
    gpio.set_dir s0
    li   s0, 0x0A
    gpio.set_out s0
    li   a1, 0xAA
    call check_in

    li   s0, 0x05
    gpio.set_bits s0
    li   a1, 0xAF
    call check_in

    li   s0, 0x03
    gpio.clr_bits s0
    li   a1, 0xAC
    call check_in

    li   s0, 0x09
    gpio.tgl_bits s0
    li   a1, 0xA5
    call check_in

    li   s0, 0x02
    gpio.set_irq_rise s0
    gpio.set_bits s0
    gpio.get_irq_status a0
    li   a1, 0x02
    call check_eq
    gpio.clr_irq_status a0
    gpio.get_irq_status a0
    li   a1, 0x00
    call check_eq

    la   a0, ok_str
    beqz s1, 1f
    la   a0, fail_str
1:  call uart_print_str
2:  wfi
    j    2b

check_in:
    gpio.get_in a0
check_eq:
    beq  a0, a1, 1f
    addi s1, s1, 1
1:  ret

uart_print_str:
    li   t1, UART_BASE_ADDR
1:  lbu  t2, 0(a0)
    beqz t2, 3f
2:  lbu  t0, 0x0(t1)
    andi t0, t0, 0x20
    beqz t0, 2b
    sb   t2, 0xC(t1)
    addi a0, a0, 1
    j    1b
3:  ret

ok_str:
    .asciz "GPIO asm ok\n"
fail_str:
    .asciz "GPIO asm fail\n"
