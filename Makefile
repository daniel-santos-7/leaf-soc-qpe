WORKDIR  = work
WAVESDIR = waves

PLOT_VENV   = sw/utils/.venv
PLOT_SCRIPT = sw/utils/plot_samples.py

GHDL = ghdl
GHDLFLAGS = --workdir=$(WORKDIR) --ieee=synopsys
GHDLXOPTS = --ieee-asserts=disable --max-stack-alloc=1024

CPU_RTL  = $(wildcard ./ips/cpu/rtl/*.vhdl)
CPU_TBS  = $(wildcard ./ips/cpu/tbs/*.vhdl)
UART_RTL = $(wildcard ./ips/uart/rtl/*.vhdl)
UART_TBS = $(wildcard ./ips/uart/tbs/*.vhdl)
WGEN_RTL = $(wildcard ./ips/wgen/rtl/*.vhd)
WGEN_TBS = $(wildcard ./ips/wgen/tbs/*.vhd)
SOC_RTL  = $(wildcard ./soc/rtl/*.vhdl)
SOC_TBS  = $(wildcard ./soc/tbs/*.vhdl)

RTL_SRC  = $(CPU_RTL) $(UART_RTL) $(WGEN_RTL) $(SOC_RTL)
TBS_SRC  = $(UART_TBS) $(WGEN_TBS) $(SOC_TBS)

TOP_UNIT = leaf_soc_tb_sim

PROGRAM       ?= sw/asm/hello-world/hello-world.bin
RAM_INIT_FILE = $(PROGRAM)
RUN_CYCLES    ?= 500000
WGEN_IF       ?= COP

PROGRAM_NAME ?= $(shell basename $(PROGRAM) .bin)
GHW_WAVEFORM ?= $(PROGRAM_NAME).ghw
FST_WAVEFORM ?= $(PROGRAM_NAME).fst
SAMPLES_CSV  ?= $(PROGRAM_NAME).csv

ifeq ($(WAVEFORM),ghw)
GHDLXOPTS += --wave=$(WAVESDIR)/$(GHW_WAVEFORM)
endif

ifeq ($(WAVEFORM),fst)
GHDLXOPTS += --fst=$(WAVESDIR)/$(FST_WAVEFORM)
endif

GHDLXOPTS += $(if $(filter 1,$(SAMPLES)),-gSAMPLES_FILE=$(WAVESDIR)/$(SAMPLES_CSV),)
GHDLXOPTS += $(if $(filter MMIO,$(WGEN_IF)),-gWGEN_IF_COP=false,)

$(WORKDIR) $(WAVESDIR):
	mkdir -p $@

FORCE:

$(WORKDIR)/program.bin: FORCE | $(WORKDIR)
	@if [ -n "$(RAM_INIT_FILE)" ]; then \
	    cp -f "$(RAM_INIT_FILE)" "$@"; \
	else \
	    rm -f "$@"; \
	fi

# Piping GHDL into tee put tee's exit status at the end of the pipeline, so
# analysis/elaboration errors were swallowed, the stamp file was created
# anyway, and `make run` reported success on a design that never built.
$(WORKDIR)/.import: $(RTL_SRC) $(TBS_SRC) | $(WORKDIR)
	@$(GHDL) -i $(GHDLFLAGS) $(RTL_SRC) $(TBS_SRC)
	@touch $@

$(WORKDIR)/.make: $(WORKDIR)/.import $(WORKDIR)/program.bin
	@$(GHDL) -m $(GHDLFLAGS) $(TOP_UNIT)
	@touch $@

.PHONY: run plot clean
run: $(WORKDIR)/.make $(PROGRAM) | $(WAVESDIR)
ifneq ($(RAM_INIT_FILE),)
	@$(GHDL) -r $(GHDLFLAGS) $(TOP_UNIT) $(GHDLXOPTS) -gPROGRAM=$(PROGRAM) -gSKIP_UART_LOAD=true -gRUN_CYCLES=$(RUN_CYCLES)
else
	@$(GHDL) -r $(GHDLFLAGS) $(TOP_UNIT) $(GHDLXOPTS) -gPROGRAM=$(PROGRAM) -gRUN_CYCLES=$(RUN_CYCLES)
endif

$(PLOT_VENV)/bin/python3: sw/utils/requirements.txt
	python3 -m venv $(PLOT_VENV)
	$(PLOT_VENV)/bin/python3 -m pip install -q -r $<

# Runs the simulation with sample capture forced on, then plots
# waves/<program>.csv -> waves/<program>.png.
plot: SAMPLES := 1
plot: run $(PLOT_VENV)/bin/python3
	$(PLOT_VENV)/bin/python3 $(PLOT_SCRIPT) $(WAVESDIR)/$(SAMPLES_CSV)

clean:
	$(GHDL) clean --workdir=$(WORKDIR)
	rm -rf .import .make $(WORKDIR) $(WAVESDIR) $(PLOT_VENV)
