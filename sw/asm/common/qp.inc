# WGEN global register layout (non-banked)
# Each register has a fixed CSR address.
# wgx_csrs: FTW(0), POW(1), AMP(2), DRAG(3), ENV(4), DELAY(5), TRIG(6)
# CSR base = 0x7C0

.equ WG_FTW,   0x7C0
.equ WG_POW,   0x7C1
.equ WG_AMP,   0x7C2
.equ WG_DRAG,  0x7C3
.equ WG_ENV,   0x7C4
.equ WG_DELAY, 0x7C5
.equ WG_TRIG,  0x7C6

.macro qp.ftw reg
    csrw WG_FTW, \reg
.endm

.macro qp.pow reg
    csrw WG_POW, \reg
.endm

.macro qp.amp reg
    csrw WG_AMP, \reg
.endm

.macro qp.drag reg
    csrw WG_DRAG, \reg
.endm

.macro qp.env reg
    csrw WG_ENV, \reg
.endm

.macro qp.delay reg
    csrw WG_DELAY, \reg
.endm

.macro qp.trigger
    csrwi WG_TRIG, 1
.endm
