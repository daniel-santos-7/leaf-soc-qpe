APP_EXE  = pulse-seq
APP_SRC  = start.S

RISCV_GCC_OPTS = -nostartfiles -nostdlib -Ttext 0x80000000 -march=$(MARCH) -mabi=$(MABI) -O0

include ../common/common.mk
