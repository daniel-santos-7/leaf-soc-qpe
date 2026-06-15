.equ WGEN_CSR_FTW,  0x7C0
.equ WGEN_CSR_POW,  0x7C1
.equ WGEN_CSR_AMP,  0x7C2
.equ WGEN_CSR_ENV,  0x7C3
.equ WGEN_CSR_DRAG, 0x7C4
.equ WGEN_CSR_DELAY, 0x7C5
.equ WGEN_CSR_TRIG, 0x7C6

.equ WGEN_CSR_INC,  WGEN_CSR_FTW
.equ WGEN_CSR_PHA,  WGEN_CSR_POW

.macro xwg.ftw reg
    csrw WGEN_CSR_FTW, \reg
.endm

.macro xwg.pow reg
    csrw WGEN_CSR_POW, \reg
.endm

.macro xwg.amp reg
    csrw WGEN_CSR_AMP, \reg
.endm

.macro xwg.env reg
    csrw WGEN_CSR_ENV, \reg
.endm

.macro xwg.drag reg
    csrw WGEN_CSR_DRAG, \reg
.endm

.macro xwg.delay reg
    csrw WGEN_CSR_DELAY, \reg
.endm

.macro xwg.trigger
    csrwi WGEN_CSR_TRIG, 1
.endm

.macro xwg.setup r_ftw, r_pow, r_amp
    xwg.ftw   \r_ftw
    xwg.pow   \r_pow
    xwg.amp   \r_amp
    xwg.env   x0
    xwg.drag  x0
    xwg.delay x0
    xwg.trigger
.endm

.macro xwg.inc reg
    xwg.ftw \reg
.endm

.macro xwg.pha reg
    xwg.pow \reg
.endm

.macro xwg.apply
    xwg.trigger
.endm
