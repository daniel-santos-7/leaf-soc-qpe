# QPE over MMIO: base and register offsets (IO1)
.equ QPE_MMIO_BASE,  0x10001000
.equ QPE_MMIO_FTW,   0x00
.equ QPE_MMIO_POW,   0x04
.equ QPE_MMIO_AMP,   0x08
.equ QPE_MMIO_DRAG,  0x0C
.equ QPE_MMIO_ENV,   0x10
.equ QPE_MMIO_DELAY, 0x14
.equ QPE_MMIO_TRIG,  0x18
.equ QPE_MMIO_CTRL,  0x1C

.macro qpe_mmio.ftw reg
    lui  t6, %hi(QPE_MMIO_BASE)
    sw   \reg, QPE_MMIO_FTW(t6)
.endm

.macro qpe_mmio.pow reg
    lui  t6, %hi(QPE_MMIO_BASE)
    sw   \reg, QPE_MMIO_POW(t6)
.endm

.macro qpe_mmio.amp reg
    lui  t6, %hi(QPE_MMIO_BASE)
    sw   \reg, QPE_MMIO_AMP(t6)
.endm

.macro qpe_mmio.drag reg
    lui  t6, %hi(QPE_MMIO_BASE)
    sw   \reg, QPE_MMIO_DRAG(t6)
.endm

.macro qpe_mmio.env reg
    lui  t6, %hi(QPE_MMIO_BASE)
    sw   \reg, QPE_MMIO_ENV(t6)
.endm

.macro qpe_mmio.delay reg
    lui  t6, %hi(QPE_MMIO_BASE)
    sw   \reg, QPE_MMIO_DELAY(t6)
.endm

.macro qpe_mmio.trigger
    lui  t6, %hi(QPE_MMIO_BASE)
    li   t0, 1
    sw   t0, QPE_MMIO_TRIG(t6)
.endm

.macro qpe_mmio.wait
    lui  t6, %hi(QPE_MMIO_BASE)
1:  lw   t0, QPE_MMIO_TRIG(t6)
    andi t0, t0, 2
    beqz t0, 1b
.endm
