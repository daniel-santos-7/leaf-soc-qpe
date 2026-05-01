.equ WGEN_CSR_INC,  0x7C0
.equ WGEN_CSR_PHA,  0x7C1
.equ WGEN_CSR_AMP,  0x7C2
.equ WGEN_CSR_CTRL, 0x7C3

.macro xwg.inc reg
    csrw WGEN_CSR_INC, \reg
.endm

.macro xwg.pha reg
    csrw WGEN_CSR_PHA, \reg
.endm

.macro xwg.amp reg
    csrw WGEN_CSR_AMP, \reg
.endm

.macro xwg.ctrl reg
    csrw WGEN_CSR_CTRL, \reg
.endm

.macro xwg.apply
    csrwi WGEN_CSR_CTRL, 1
.endm

.macro xwg.setup r_inc, r_pha, r_amp
    xwg.inc \r_inc
    xwg.pha \r_pha
    xwg.amp \r_amp
    xwg.apply
.endm
