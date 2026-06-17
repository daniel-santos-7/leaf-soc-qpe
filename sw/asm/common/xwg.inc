.equ WGEN_CSR_FTW,  0x7C0
.equ WGEN_CSR_POW,  0x7C1
.equ WGEN_CSR_AMP,  0x7C2
.equ WGEN_CSR_ENV,  0x7C3
.equ WGEN_CSR_DRAG, 0x7C4
.equ WGEN_CSR_DELAY, 0x7C5
.equ WGEN_CSR_STAT, 0x7C6
.equ WGEN_CSR_SEQ_LEN,    0x7C7
.equ WGEN_CSR_SEQ_PTR,    0x7C8
.equ WGEN_CSR_SEQ_DATA,   0x7C9
.equ WGEN_CSR_SEQ_CTRL,   0x7CA
.equ WGEN_CSR_SEQ_REPEAT, 0x7CB

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
    csrwi WGEN_CSR_SEQ_LEN, 1
    csrwi WGEN_CSR_SEQ_CTRL, 1
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

.macro xwg.seq_ptr imm
    csrwi WGEN_CSR_SEQ_PTR, \imm
.endm

.macro xwg.seq_data reg
    csrw WGEN_CSR_SEQ_DATA, \reg
.endm

.macro xwg.seq_entry ptr, r_ftw, r_pow, r_amp, r_env, r_drag, r_delay
    csrwi WGEN_CSR_SEQ_PTR, \ptr
    csrw  WGEN_CSR_SEQ_DATA, \r_ftw
    csrw  WGEN_CSR_SEQ_DATA, \r_pow
    csrw  WGEN_CSR_SEQ_DATA, \r_amp
    csrw  WGEN_CSR_SEQ_DATA, \r_env
    csrw  WGEN_CSR_SEQ_DATA, \r_drag
    csrw  WGEN_CSR_SEQ_DATA, \r_delay
.endm

.macro xwg.seq_len imm
    csrwi WGEN_CSR_SEQ_LEN, \imm
.endm

.macro xwg.seq_repeat imm
    csrwi WGEN_CSR_SEQ_REPEAT, \imm
.endm

.macro xwg.seq_start
    csrwi WGEN_CSR_SEQ_CTRL, 1
.endm
