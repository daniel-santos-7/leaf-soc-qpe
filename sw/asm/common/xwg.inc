# WGEN CSRs (COP register map, matches sig_gen_csrs)
.equ WGEN_CSR_FTW,   0x7C0
.equ WGEN_CSR_POW,   0x7C1
.equ WGEN_CSR_AMP,   0x7C2
.equ WGEN_CSR_ENV,   0x7C3
.equ WGEN_CSR_DELAY, 0x7C4
.equ WGEN_CSR_TRIG,  0x7C5
.equ WGEN_CSR_CTRL,  0x7C6

.macro xwg.ftw reg
    csrw WGEN_CSR_FTW, \reg
.endm

.macro xwg.pow reg
    csrw WGEN_CSR_POW, \reg
.endm

.macro xwg.env reg
    csrw WGEN_CSR_ENV, \reg
.endm

# AMP: combined {drag[15:0], amp[15:0]} — caller packs the value
.macro xwg.amp_drag reg
    csrw WGEN_CSR_AMP, \reg
.endm

.macro xwg.delay reg
    csrw WGEN_CSR_DELAY, \reg
.endm

# TRIG: write bit 0 = valid (push), read: bit 1 = ready, bit 0 = valid
.macro xwg.push
    csrwi WGEN_CSR_TRIG, 1
.endm

.macro xwg.trig rd
    csrr \rd, WGEN_CSR_TRIG
.endm

# CTRL: write bit 0 = start
.macro xwg.start
    csrwi WGEN_CSR_CTRL, 1
.endm

.macro xwg.push_start
    csrwi WGEN_CSR_TRIG, 1
    csrwi WGEN_CSR_CTRL, 1
.endm
