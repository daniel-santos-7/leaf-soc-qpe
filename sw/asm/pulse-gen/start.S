# pulse-gen: Microwave pulse generator for superconducting qubit control
# Clock: 50 MHz (20 ns/cycle)
# Interface: COP CSR (xwg macros)

.equ UART_BASE_ADDR, 0x10000000
.equ RAM_TOP,        0x80010000

# pi-pulse (4 us): FTW=5 MHz, AMP=2047, ENV=200 cyc, DRAG=0.2
.equ FTW_PI,         0x1999999A
.equ AMP_PI,         0x000007FF
.equ ENV_PI,         0x0147AE14
.equ DRAG_PI,        0x00001999

# pi/2-pulse (2 us): same FTW, half AMP, ENV=100 cyc, DRAG=0.2
.equ AMP_PI2,        0x00000400
.equ ENV_PI2,        0x028F5C29

# Readout pulse (10 us): FTW=10 MHz, AMP=3072, ENV=500 cyc, DRAG=0
.equ FTW_READOUT,    0x33333333
.equ AMP_READOUT,    0x00000C00
.equ ENV_READOUT,    0x0083126F

.include "../common/xwg.inc"

.section .text
.globl _start

_start:
    li sp, RAM_TOP

    li s0, FTW_PI
    li s1, 0
    li s2, AMP_PI
    li s3, ENV_PI
    li s4, DRAG_PI
    li s5, 0

    la a0, banner_str
    call uart_print_str

    # Auto-fire pi-pulse on startup for simulation/hardware test
    la a0, fire_str
    call uart_print_str
    call fire_pulse

main_loop:
    la a0, prompt_str
    call uart_print_str

    call uart_read
    mv t0, a0

    li t1, '1'
    beq t0, t1, cmd_pi
    li t1, '2'
    beq t0, t1, cmd_pi2
    li t1, '3'
    beq t0, t1, cmd_readout
    li t1, 't'
    beq t0, t1, cmd_trigger
    li t1, 'b'
    beq t0, t1, cmd_burst
    li t1, 's'
    beq t0, t1, cmd_status
    li t1, 'h'
    beq t0, t1, cmd_help

    la a0, err_str
    call uart_print_str
    j main_loop

cmd_pi:
    li s0, FTW_PI
    li s1, 0
    li s2, AMP_PI
    li s3, ENV_PI
    li s4, DRAG_PI
    li s5, 0
    call fire_pulse
    j main_loop

cmd_pi2:
    li s0, FTW_PI
    li s1, 0
    li s2, AMP_PI2
    li s3, ENV_PI2
    li s4, DRAG_PI
    li s5, 0
    call fire_pulse
    j main_loop

cmd_readout:
    li s0, FTW_READOUT
    li s1, 0
    li s2, AMP_READOUT
    li s3, ENV_READOUT
    li s4, 0
    li s5, 0
    call fire_pulse
    j main_loop

cmd_trigger:
    call fire_pulse
    j main_loop

cmd_burst:
    call parse_dec
    mv t0, a0
1:
    beqz t0, 2f
    call fire_pulse
    addi t0, t0, -1
    j 1b
2:
    j main_loop

cmd_status:
    la a0, ftw_lbl
    call uart_print_str
    mv a0, s0
    call uart_print_hex32

    la a0, pow_lbl
    call uart_print_str
    mv a0, s1
    call uart_print_hex32

    la a0, amp_lbl
    call uart_print_str
    mv a0, s2
    call uart_print_dec

    la a0, env_lbl
    call uart_print_str
    mv a0, s3
    call uart_print_hex32

    la a0, drag_lbl
    call uart_print_str
    mv a0, s4
    call uart_print_hex32

    la a0, delay_lbl
    call uart_print_str
    mv a0, s5
    call uart_print_dec

    la a0, ready_lbl
    call uart_print_str
    xwg.trig t0
    srli t0, t0, 1
    andi t0, t0, 1
    mv a0, t0
    call uart_print_dec
    la a0, nl
    call uart_print_str
    j main_loop

cmd_help:
    la a0, help_str
    call uart_print_str
    j main_loop

// --------------------------------------------------
// fire_pulse
// --------------------------------------------------
fire_pulse:
    xwg.ftw      s0
    xwg.pow      s1
    slli t0, s4, 16
    or   t0, t0, s2
    xwg.amp_drag t0
    xwg.env      s3
    xwg.delay    s5
    xwg.push_start
1:  xwg.trig t0
    andi t0, t0, 2
    beqz t0, 1b
    la a0, ok_str
    call uart_print_str
    ret

// --------------------------------------------------
// uart_read
// --------------------------------------------------
uart_read:
    li t1, UART_BASE_ADDR
1:
    lbu t0, 0x0(t1)
    andi t0, t0, 0x4
    beqz t0, 1b
    lbu a0, 0xC(t1)
    ret

// --------------------------------------------------
// uart_write
// --------------------------------------------------
uart_write:
    li  t1, UART_BASE_ADDR
1:
    lbu t0, 0x0(t1)
    andi t0, t0, 0x20
    beqz t0, 1b
    andi a0, a0, 0xFF
    sb   a0, 0xC(t1)
    ret

// --------------------------------------------------
// uart_print_str
// --------------------------------------------------
uart_print_str:
    addi sp, sp, -4
    sw   ra, 0(sp)
    mv   t2, a0
1:
    lbu  t0, 0(t2)
    beqz t0, 2f
    mv   a0, t0
    addi sp, sp, -4
    sw   t2, 0(sp)
    call uart_write
    lw   t2, 0(sp)
    addi sp, sp, 4
    addi t2, t2, 1
    j    1b
2:
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

// --------------------------------------------------
// uart_print_hex32: print a0 as 8 hex digits
// --------------------------------------------------
uart_print_hex32:
    addi sp, sp, -4
    sw   ra, 0(sp)
    li   t2, 8
    mv   t3, a0
1:
    srli t0, t3, 28
    andi t0, t0, 0xF
    li   t1, 10
    blt  t0, t1, 2f
    addi t0, t0, 0x57
    j    3f
2:
    addi t0, t0, 0x30
3:
    mv   a0, t0
    addi sp, sp, -8
    sw   t2, 0(sp)
    sw   t3, 4(sp)
    call uart_write
    lw   t2, 0(sp)
    lw   t3, 4(sp)
    addi sp, sp, 8
    slli t3, t3, 4
    addi t2, t2, -1
    bnez t2, 1b
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

// --------------------------------------------------
// uart_print_dec: print a0 as decimal (RV32I, no mul/div)
// --------------------------------------------------
uart_print_dec:
    addi sp, sp, -16
    sw   ra, 12(sp)
    mv   t3, sp
    addi t5, sp, 11
    sb   zero, 0(t5)

    li   t0, 10
    call __divmod
    addi t0, t1, 0x30
    addi t5, t5, -1
    sb   t0, 0(t5)
    beqz a0, 3f

    li   t0, 10
    call __divmod
    addi t0, t1, 0x30
    addi t5, t5, -1
    sb   t0, 0(t5)
    beqz a0, 3f

    li   t0, 10
    call __divmod
    addi t0, t1, 0x30
    addi t5, t5, -1
    sb   t0, 0(t5)
    beqz a0, 3f

    li   t0, 10
    call __divmod
    addi t0, t1, 0x30
    addi t5, t5, -1
    sb   t0, 0(t5)
    beqz a0, 3f

    li   t0, 10
    call __divmod
    addi t0, t1, 0x30
    addi t5, t5, -1
    sb   t0, 0(t5)

3:
    mv   a0, t5
    call uart_print_str
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

// --------------------------------------------------
// __divmod: a0 = dividend, t0 = divisor
// Returns: a0 = quotient, t1 = remainder
// --------------------------------------------------
__divmod:
    li t1, 0
    mv t2, a0
    li a0, 0
    li t3, 32
1:
    slli t1, t1, 1
    srli t4, t2, 31
    or t1, t1, t4
    slli t2, t2, 1
    slli a0, a0, 1
    bltu t1, t0, 2f
    sub t1, t1, t0
    ori a0, a0, 1
2:
    addi t3, t3, -1
    bnez t3, 1b
    ret

# --------------------------------------------------
# parse_dec: read decimal number from UART
# Returns: a0 = value
# --------------------------------------------------
parse_dec:
    li t0, 0
1:
    addi sp, sp, -4
    sw t0, 0(sp)
    call uart_read
    lw t1, 0(sp)
    addi sp, sp, 4

    li t2, 0x30
    blt a0, t2, 2f
    li t2, 0x39
    bgt a0, t2, 2f

    andi a0, a0, 0xFF
    addi a0, a0, -0x30

    // t1 = t1 * 10 + digit
    // 10 = 8 + 2
    slli t2, t1, 3
    slli t1, t1, 1
    add t1, t2, t1
    add t1, t1, a0

    j 1b
2:
    mv a0, t1
    ret

# --------------------------------------------------
# Strings
# --------------------------------------------------
banner_str:
    .asciz "\npulse-gen: Microwave pulse generator\n"
fire_str:
    .asciz "Pi-pulse...\n"
prompt_str:
    .asciz "> "
ok_str:
    .asciz "OK\n"
err_str:
    .asciz "?\n"
nl:
    .asciz "\n"
ftw_lbl:
    .asciz "FTW="
pow_lbl:
    .asciz " POW="
amp_lbl:
    .asciz " AMP="
env_lbl:
    .asciz " ENV="
drag_lbl:
    .asciz " DRAG="
delay_lbl:
    .asciz " DELAY="
ready_lbl:
    .asciz " READY="
help_str:
    .asciz "1  Pi-pulse (4us)\n2  Pi/2-pulse (2us)\n3  Readout pulse (10us)\nt  Trigger with current params\nb  Burst (read N, fire N pulses)\ns  Show status\nh  Help\n"
