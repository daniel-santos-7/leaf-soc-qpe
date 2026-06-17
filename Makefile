GHDL = ghdl
GHDLFLAGS = --workdir=$(WORKDIR) --ieee=synopsys
GHDLXOPTS = --ieee-asserts=disable

WORKDIR  = work
WAVESDIR = waves

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

TOP_TB = leaf_soc_tb

PROGRAM  ?= sw/asm/hello-world/hello-world.bin
RUN_CYCLES ?= 500000
WGEN_IF  ?= COP
WAVEFORM ?= $(shell basename $(PROGRAM) .bin).fst

# Generated config package
WGEN_CFG = soc/rtl/wgen_cfg.vhdl

ifeq ($(WGEN_IF),MMIO)
WGEN_CFG_BOOL := false
else
WGEN_CFG_BOOL := true
endif

ifdef WAVEFORM
override GHDLXOPTS += --fst=$(WAVESDIR)/$(WAVEFORM)
endif

$(WORKDIR) $(WAVESDIR):
	mkdir -p $@

$(WGEN_CFG): | soc/rtl
	echo 'package wgen_cfg is constant WGEN_IF_COP : boolean := $(WGEN_CFG_BOOL); end package wgen_cfg;' > $@

$(WORKDIR)/.import: $(RTL_SRC) $(TBS_SRC) $(WGEN_CFG) | $(WORKDIR)
	$(GHDL) -i $(GHDLFLAGS) $(RTL_SRC) $(TBS_SRC) $(WGEN_CFG) | tee $@

$(WORKDIR)/.make: $(WORKDIR)/.import
	$(GHDL) -m $(GHDLFLAGS) $(TOP_TB) | tee $@

rtl.tar.gz: $(CPU_RTL) $(UART_RTL) $(WGEN_RTL) $(SOC_RTL)
	mkdir -p /tmp/rtl-archive
	cp $(CPU_RTL) $(UART_RTL) $(WGEN_RTL) $(SOC_RTL) /tmp/rtl-archive/
	tar -czvf $@ -C /tmp/rtl-archive .
	rm -rf /tmp/rtl-archive

.PHONY: run clean
run: $(WORKDIR)/.make $(PROGRAM) | $(WAVESDIR)
	$(GHDL) -r $(GHDLFLAGS) $(TOP_TB) $(GHDLXOPTS) -gPROGRAM=$(PROGRAM) -gRUN_CYCLES=$(RUN_CYCLES)

clean:
	$(GHDL) clean --workdir=$(WORKDIR)
	rm -f $(WGEN_CFG)
	rm -rf .import .make $(WORKDIR) $(WAVESDIR)
