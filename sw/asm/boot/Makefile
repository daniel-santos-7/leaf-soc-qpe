RISCV_PREFIX  = riscv32-unknown-elf
RISCV_GCC     = $(RISCV_PREFIX)-gcc
RISCV_OBJDUMP = $(RISCV_PREFIX)-objdump
RISCV_OBJCOPY = $(RISCV_PREFIX)-objcopy

MARCH = rv32i
MABI  = ilp32

APP_EXE  = boot
APP_SRC  = start.S crc.S ../common/uart.S

RISCV_GCC_OPTS = -nostartfiles -nostdlib -Ttext 0x00001000 -march=$(MARCH) -mabi=$(MABI) -O0

.PHONY: all clean
all: $(APP_EXE).elf $(APP_EXE).bin $(APP_EXE).debug $(APP_EXE)_pkg.vhdl

$(APP_EXE).elf: $(APP_SRC)
	$(RISCV_GCC) $(RISCV_GCC_OPTS) $^ -o $@

$(APP_EXE).bin: $(APP_EXE).elf
	$(RISCV_OBJCOPY) -O binary $^ $@

$(APP_EXE).debug: $(APP_EXE).elf
	$(RISCV_OBJDUMP) $^ --source > $@

$(APP_EXE)_pkg.vhdl: boot.py $(APP_EXE).bin
	python3 boot.py $(APP_EXE).bin 512 > $@

.PHONY: clean
clean:
	rm -f $(APP_EXE).elf $(APP_EXE).bin $(APP_EXE).debug $(APP_EXE)_pkg.vhdl
