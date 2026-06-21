# WGEN CSR bank layout
# Each bank = 5 consecutive addrs (FTW, POW, AMP, ENV, DEL)
# Banks 0-11 at base 0x00..0x3B (CSR addrs 0x7C0..0x7FB)
# CTRL at addr 0x3F (CSR addr 0x7FF)

.equ WG_BANK_BASE,   0x7C0
.equ WG_BANK_STRIDE, 5

.equ WG_FTW, 0
.equ WG_POW, 1
.equ WG_AMP, 2
.equ WG_ENV, 3
.equ WG_DEL, 4

.equ WG_CSR_CTRL, 0x7FF

.macro xwg.ftw bank, reg
    csrw WG_BANK_BASE + (\bank * WG_BANK_STRIDE + WG_FTW), \reg
.endm

.macro xwg.pow bank, reg
    csrw WG_BANK_BASE + (\bank * WG_BANK_STRIDE + WG_POW), \reg
.endm

# AMP = {drag[15:0], amp[15:0]}
.macro xwg.amp bank, reg
    csrw WG_BANK_BASE + (\bank * WG_BANK_STRIDE + WG_AMP), \reg
.endm

.macro xwg.env bank, reg
    csrw WG_BANK_BASE + (\bank * WG_BANK_STRIDE + WG_ENV), \reg
.endm

.macro xwg.delay bank, reg
    csrw WG_BANK_BASE + (\bank * WG_BANK_STRIDE + WG_DEL), \reg
.endm

.macro xwg.start count
    li t0, ((\count & 0xF) << 4) | 1
    csrw WG_CSR_CTRL, t0
.endm
