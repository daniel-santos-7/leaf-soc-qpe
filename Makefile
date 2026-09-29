WORKDIR  = work
WAVESDIR = waves
DISTDIR  = dist

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
GPIO_RTL = $(wildcard ./ips/gpio/rtl/*.vhd)
SOC_RTL  = $(wildcard ./soc/rtl/*.vhdl)
SOC_TBS  = $(wildcard ./soc/tbs/*.vhdl)
TECH_DIR ?= ./tech
TECH_SRC = $(wildcard $(TECH_DIR)/*.vhdl)

RTL_SRC  = $(CPU_RTL) $(UART_RTL) $(WGEN_RTL) $(GPIO_RTL) $(SOC_RTL)
TBS_SRC  = $(UART_TBS) $(WGEN_TBS) $(SOC_TBS) $(TECH_SRC)

RTL_TECH  = $(if $(filter TECH,$(RAM)),$(addprefix $(TECH_DIR)/,$(shell cat $(TECH_DIR)/syn.f 2>/dev/null)))
RTL_TOP  ?= $(if $(filter TECH,$(RAM)),leaf_soc_tech,leaf_soc)
RTL_TAR   = $(DISTDIR)/$(RTL_TOP)_rtl.tar
RTL_WORK  = $(DISTDIR)/work
RTL_FILES = $(patsubst ./%,%,$(RTL_SRC) $(RTL_TECH))

ifneq ($(filter rtl-tar,$(MAKECMDGOALS)),)
ifeq ($(RAM),MACRO)
$(error rtl-tar: RAM=MACRO has no synthesisable macro, use BEHAV or TECH)
endif
ifeq ($(RAM)$(RTL_TECH),TECH)
$(error rtl-tar: RAM=TECH needs $(TECH_DIR)/syn.f)
endif
endif

PROGRAM       ?= sw/asm/hello-world/hello-world.bin
RAM_INIT_FILE = $(PROGRAM)
RUN_CYCLES    ?= 500000
WGEN_IF       ?= COP
RAM           ?= BEHAV

ifeq ($(RAM),BEHAV)
TOP_UNIT = leaf_soc_tb_sim
else ifeq ($(RAM),MACRO)
TOP_UNIT = leaf_soc_tb_macro
else ifeq ($(RAM),TECH)
TOP_UNIT = leaf_soc_tb_tech
ifeq ($(TECH_SRC),)
$(error RAM=TECH needs the technology sources in $(TECH_DIR))
endif
else
$(error RAM must be BEHAV, MACRO or TECH, got '$(RAM)')
endif

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

.PHONY: run plot rtl-tar clean
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

rtl-tar: $(RTL_TAR)

$(RTL_TAR): $(RTL_SRC) $(RTL_TECH)
	@rm -rf $(RTL_WORK)
	@mkdir -p $(RTL_WORK)/order $(RTL_WORK)/check $(RTL_WORK)/flat
	@$(GHDL) -i --workdir=$(RTL_WORK)/order $(RTL_FILES)
	@$(GHDL) --elab-order -Wno-binding --workdir=$(RTL_WORK)/order $(RTL_TOP) > $(RTL_WORK)/order.txt
	@for f in $(RTL_FILES); do \
	    grep -qxF "$$f" $(RTL_WORK)/order.txt || echo "$$f" >> $(RTL_WORK)/order.txt; \
	done
	@for f in $$(cat $(RTL_WORK)/order.txt); do \
	    b=$$(basename "$$f"); \
	    if [ -e "$(RTL_WORK)/flat/$$b" ]; then echo "rtl-tar: duplicate file name $$b" >&2; exit 1; fi; \
	    cp "$$f" "$(RTL_WORK)/flat/$$b"; \
	    echo "$$b" >> $(RTL_WORK)/flat/files.f; \
	done
	@cd $(RTL_WORK)/flat && $(GHDL) -a --workdir=../check $$(cat files.f)
	@tar -cf $@ -C $(RTL_WORK)/flat $$(cat $(RTL_WORK)/flat/files.f) files.f
	@rm -rf $(RTL_WORK)
	@echo "$@: $$(tar -tf $@ | wc -l) files"

clean:
	$(GHDL) clean --workdir=$(WORKDIR)
	rm -rf .import .make $(WORKDIR) $(WAVESDIR) $(DISTDIR) $(PLOT_VENV)
