APP_EXE  = gpio_test
APP_SRC  = main.c ../common/gpio.h ../common/gpio.c $(STARTUP) $(SYSCALLS)
RISCV_GCC_OPTS = -specs=nano.specs -nostartfiles -T $(LDSCRIPT) -march=$(MARCH) -mabi=$(MABI) -Os -w -fdata-sections -ffunction-sections -mno-fdiv -Wl,--gc-sections -lm -lc -lgcc -lc
include ../common/common.mk
