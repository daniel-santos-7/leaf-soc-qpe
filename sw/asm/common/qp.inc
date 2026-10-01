# WGEN global register layout (non-banked)
# Each register has a fixed CSR address.
# qpe_csrs: FTW(0), POW(1), AMP(2), DRAG(3), ENV(4), DELAY(5), TRIG(6)
# CSR base = 0x7C0

.equ WG_FTW,   0x7C0
.equ WG_POW,   0x7C1
.equ WG_AMP,   0x7C2
.equ WG_DRAG,  0x7C3
.equ WG_ENV,   0x7C4
.equ WG_DELAY, 0x7C5
.equ WG_TRIG,  0x7C6

.macro qp.ftw n
    csrwi WG_FTW, \n
.endm

.macro qp.pow n
    csrwi WG_POW, \n
.endm

.macro qp.amp n
    csrwi WG_AMP, \n
.endm

.macro qp.drag n
    csrwi WG_DRAG, \n
.endm

.macro qp.env n
    csrwi WG_ENV, \n
.endm

.macro qp.delay n
    csrwi WG_DELAY, \n
.endm

.macro qp.trigger
    csrwi WG_TRIG, 1
.endm

.macro qp.wait
1:  csrr t0, WG_TRIG
    andi t0, t0, 2
    beqz t0, 1b
.endm
