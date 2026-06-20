WORKDIR  = work
WAVESDIR = waves

GHDL = ghdl
GHDLFLAGS = --workdir=$(WORKDIR) --ieee=synopsys
GHDLXOPTS = --ieee-asserts=disable --max-stack-alloc=1024

CPU_RTL  = $(wildcard ./ips/cpu/rtl/*.vhdl)
CPU_TBS  = $(wildcard ./ips/cpu/tbs/*.vhdl)
UART_RTL = $(wildcard ./ips/uart/rtl/*.vhdl)
UART_TBS = $(wildcard ./ips/uart/tbs/*.vhdl)
SOC_RTL  = $(wildcard ./soc/rtl/*.vhdl)
SOC_TBS  = $(wildcard ./soc/tbs/*.vhdl)

RTL_SRC  = $(CPU_RTL) $(UART_RTL) $(SOC_RTL)
TBS_SRC  = $(UART_TBS) $(SOC_TBS)

TOP_UNIT = leaf_soc_tb_sim

PROGRAM       ?= sw/asm/hello-world/hello-world.bin
RAM_INIT_FILE = $(PROGRAM)
RUN_CYCLES    ?= 500000

PROGRAM_NAME ?= $(shell basename $(PROGRAM) .bin)
GHW_WAVEFORM ?= $(PROGRAM_NAME).ghw
FST_WAVEFORM ?= $(PROGRAM_NAME).fst

ifeq ($(WAVEFORM),ghw)
GHDLXOPTS += --wave=$(WAVESDIR)/$(GHW_WAVEFORM)
endif

ifeq ($(WAVEFORM),fst)
GHDLXOPTS += --fst=$(WAVESDIR)/$(FST_WAVEFORM)
endif

$(WORKDIR) $(WAVESDIR):
	@mkdir -p $@

FORCE:

$(WORKDIR)/program.bin: FORCE | $(WORKDIR)
	@if [ -n "$(RAM_INIT_FILE)" ]; then \
	    cp -f "$(RAM_INIT_FILE)" "$@"; \
	else \
	    rm -f "$@"; \
	fi

$(WORKDIR)/.import: $(RTL_SRC) $(TBS_SRC) | $(WORKDIR)
	@$(GHDL) -i $(GHDLFLAGS) $(RTL_SRC) $(TBS_SRC) | tee $@

$(WORKDIR)/.make: $(WORKDIR)/.import $(WORKDIR)/program.bin
	@$(GHDL) -m $(GHDLFLAGS) $(TOP_UNIT) 2>&1 | tee $@
	@touch $@

.PHONY: run clean
run: $(WORKDIR)/.make $(PROGRAM) | $(WAVESDIR)
ifneq ($(RAM_INIT_FILE),)
	@$(GHDL) -r $(GHDLFLAGS) $(TOP_UNIT) $(GHDLXOPTS) -gPROGRAM=$(PROGRAM) -gSKIP_UART_LOAD=true -gRUN_CYCLES=$(RUN_CYCLES)
else
	@$(GHDL) -r $(GHDLFLAGS) $(TOP_UNIT) $(GHDLXOPTS) -gPROGRAM=$(PROGRAM) -gRUN_CYCLES=$(RUN_CYCLES)
endif

clean:
	@$(GHDL) clean --workdir=$(WORKDIR)
	@rm -rf .import .make $(WORKDIR) $(WAVESDIR)
