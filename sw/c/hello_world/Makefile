APP_EXE  = hello_world
RISCV_GCC_OPTS = -specs=nano.specs -nostartfiles -T $(LDSCRIPT) -march=$(MARCH) -mabi=$(MABI) -Os -w -fdata-sections -ffunction-sections -mno-fdiv -Wl,--gc-sections -lm -lc -lgcc -lc
include ../common/common.mk
