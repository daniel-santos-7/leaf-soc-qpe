.section .text
.globl crc8_update

# --------------------------------------------------
# crc8_update
# CRC-8 (poly = 0x07, init = 0x00)
# Input:
# a0 = input byte
# a1 = current CRC
# Output:
# a0 = updated CRC
# --------------------------------------------------
crc8_update:
    andi a0, a0, 0xFF     # ensure input is a clean byte
    andi a1, a1, 0xFF     # ensure CRC is 8-bit
    xor  a0, a0, a1       # crc ^= byte
    li   t0, 8            # bit loop counter
1:
    slli a0, a0, 1        # crc <<= 1
    bgez a0, 2f           # if previous MSB was 0, skip polynomial
    xori a0, a0, 0x07     # apply polynomial (x^8 + x^2 + x + 1)
2:
    addi t0, t0, -1
    bnez t0, 1b
    andi a0, a0, 0xFF     # keep CRC within 8 bits
    ret
