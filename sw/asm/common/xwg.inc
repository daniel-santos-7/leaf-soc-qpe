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

# AMP: combined {drag[15:0], amp[15:0]}
.macro xwg.amp reg
    csrr t0, WGEN_CSR_AMP
    li   t1, 0xFFFF0000
    and  t0, t0, t1
    or   t0, t0, \reg
    csrw WGEN_CSR_AMP, t0
.endm

.macro xwg.env reg
    csrw WGEN_CSR_ENV, \reg
.endm

# DRAG: combined into AMP upper half (read-modify-write)
.macro xwg.drag reg
    csrr t0, WGEN_CSR_AMP
    li   t1, 0xFFFF
    and  t0, t0, t1
    slli t1, \reg, 16
    or   t0, t0, t1
    csrw WGEN_CSR_AMP, t0
.endm

# Write amp and drag atomically
.macro xwg.amp_drag amp_reg, drag_reg
    slli t0, \drag_reg, 16
    li   t1, 0xFFFF
    and  t1, \amp_reg, t1
    or   t0, t0, t1
    csrw WGEN_CSR_AMP, t0
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
