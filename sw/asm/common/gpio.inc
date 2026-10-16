# GPIO on IO2: base and register offsets
.equ GPIO_BASE,           0x10002000
.equ GPIO_OFF_DATA_IN,    0x00
.equ GPIO_OFF_DATA_OUT,   0x04
.equ GPIO_OFF_DIR,        0x08
.equ GPIO_OFF_SET,        0x0C
.equ GPIO_OFF_CLR,        0x10
.equ GPIO_OFF_TGL,        0x14
.equ GPIO_OFF_IRQ_RISE,   0x18
.equ GPIO_OFF_IRQ_FALL,   0x1C
.equ GPIO_OFF_IRQ_STATUS, 0x20

.macro gpio.set_dir reg
    lui  t6, %hi(GPIO_BASE)
    sw   \reg, GPIO_OFF_DIR(t6)
.endm

.macro gpio.get_dir rd
    lui  t6, %hi(GPIO_BASE)
    lw   \rd, GPIO_OFF_DIR(t6)
.endm

.macro gpio.get_in rd
    lui  t6, %hi(GPIO_BASE)
    lw   \rd, GPIO_OFF_DATA_IN(t6)
.endm

.macro gpio.set_out reg
    lui  t6, %hi(GPIO_BASE)
    sw   \reg, GPIO_OFF_DATA_OUT(t6)
.endm

.macro gpio.get_out rd
    lui  t6, %hi(GPIO_BASE)
    lw   \rd, GPIO_OFF_DATA_OUT(t6)
.endm

.macro gpio.set_bits reg
    lui  t6, %hi(GPIO_BASE)
    sw   \reg, GPIO_OFF_SET(t6)
.endm

.macro gpio.clr_bits reg
    lui  t6, %hi(GPIO_BASE)
    sw   \reg, GPIO_OFF_CLR(t6)
.endm

.macro gpio.tgl_bits reg
    lui  t6, %hi(GPIO_BASE)
    sw   \reg, GPIO_OFF_TGL(t6)
.endm

.macro gpio.set_irq_rise reg
    lui  t6, %hi(GPIO_BASE)
    sw   \reg, GPIO_OFF_IRQ_RISE(t6)
.endm

.macro gpio.get_irq_rise rd
    lui  t6, %hi(GPIO_BASE)
    lw   \rd, GPIO_OFF_IRQ_RISE(t6)
.endm

.macro gpio.set_irq_fall reg
    lui  t6, %hi(GPIO_BASE)
    sw   \reg, GPIO_OFF_IRQ_FALL(t6)
.endm

.macro gpio.get_irq_fall rd
    lui  t6, %hi(GPIO_BASE)
    lw   \rd, GPIO_OFF_IRQ_FALL(t6)
.endm

.macro gpio.get_irq_status rd
    lui  t6, %hi(GPIO_BASE)
    lw   \rd, GPIO_OFF_IRQ_STATUS(t6)
.endm

.macro gpio.clr_irq_status reg
    lui  t6, %hi(GPIO_BASE)
    sw   \reg, GPIO_OFF_IRQ_STATUS(t6)
.endm
