APP_EXE  = coremark

CORE_DEBUG ?= 0

APP_SRC  = core_list_join.c core_main.c core_matrix.c core_portme.c core_state.c core_util.c ee_printf.c $(STARTUP) $(SYSCALLS)

STARTUP  ?= ../c/common/crt0.S
SYSCALLS ?= ../c/common/syscalls.c
LDSCRIPT ?= ../c/common/soc.ld

RISCV_GCC_OPTS = -nostartfiles -T $(LDSCRIPT) -march=$(MARCH) -mabi=$(MABI) -O1 -w -fdata-sections -ffunction-sections -mno-fdiv -Wl,--gc-sections -DPERFORMANCE_RUN=1 -DCORE_DEBUG=$(CORE_DEBUG) -DITERATIONS=1000

include ../c/common/common.mk