# QPE over the coprocessor CSR window
# qpe_csrs: FTW(0), POW(1), AMP(2), DRAG(3), ENV(4), DELAY(5), TRIG(6)
# CSR base = 0x7C0

.equ QPE_CSR_FTW,   0x7C0
.equ QPE_CSR_POW,   0x7C1
.equ QPE_CSR_AMP,   0x7C2
.equ QPE_CSR_DRAG,  0x7C3
.equ QPE_CSR_ENV,   0x7C4
.equ QPE_CSR_DELAY, 0x7C5
.equ QPE_CSR_TRIG,  0x7C6

.macro qpe.ftw n
    csrwi QPE_CSR_FTW, \n
.endm

.macro qpe.pow n
    csrwi QPE_CSR_POW, \n
.endm

.macro qpe.amp n
    csrwi QPE_CSR_AMP, \n
.endm

.macro qpe.drag n
    csrwi QPE_CSR_DRAG, \n
.endm

.macro qpe.env n
    csrwi QPE_CSR_ENV, \n
.endm

.macro qpe.delay n
    csrwi QPE_CSR_DELAY, \n
.endm

.macro qpe.trigger
    csrwi QPE_CSR_TRIG, 1
.endm

.macro qpe.wait
1:  csrr t0, QPE_CSR_TRIG
    andi t0, t0, 2
    beqz t0, 1b
.endm
