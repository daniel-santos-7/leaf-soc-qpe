# Wave generator MMIO base and register offsets (IO1)
.equ WGEN_BASE,     0x10001000
.equ WGEN_FTW,      0x00
.equ WGEN_POW,      0x04
.equ WGEN_AMP,      0x08
.equ WGEN_DRAG,     0x0C
.equ WGEN_ENV,      0x10
.equ WGEN_DELAY,    0x14
.equ WGEN_TRIG,     0x18
.equ WGEN_CTRL,     0x1C

.macro wg.ftw reg
    lui  t6, %hi(WGEN_BASE)
    sw   \reg, WGEN_FTW(t6)
.endm

.macro wg.pow reg
    lui  t6, %hi(WGEN_BASE)
    sw   \reg, WGEN_POW(t6)
.endm

.macro wg.amp reg
    lui  t6, %hi(WGEN_BASE)
    sw   \reg, WGEN_AMP(t6)
.endm

.macro wg.drag reg
    lui  t6, %hi(WGEN_BASE)
    sw   \reg, WGEN_DRAG(t6)
.endm

.macro wg.env reg
    lui  t6, %hi(WGEN_BASE)
    sw   \reg, WGEN_ENV(t6)
.endm

.macro wg.delay reg
    lui  t6, %hi(WGEN_BASE)
    sw   \reg, WGEN_DELAY(t6)
.endm

.macro wg.trigger
    lui  t6, %hi(WGEN_BASE)
    li   t0, 1
    sw   t0, WGEN_TRIG(t6)
.endm

.macro wg.wait
    lui  t6, %hi(WGEN_BASE)
1:  lw   t0, WGEN_TRIG(t6)
    andi t0, t0, 2
    beqz t0, 1b
.endm
