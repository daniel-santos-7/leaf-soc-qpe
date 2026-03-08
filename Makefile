# leaf project

# VHDL simulator
GHDL = ghdl
GHDLFLAGS = --workdir=$(WORKDIR) --ieee=synopsys
GHDLXOPTS = --ieee-asserts=disable --stop-time=10ms

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
TBS_SRC  = $(CPU_TBS) $(UART_TBS) $(WGEN_TBS) $(SOC_TBS)

TOP_TB = leaf_soc_tb

PROGRAM  ?= sw/asm/hello-world/hello-world.bin
WAVEFORM ?= $(shell basename $(PROGRAM) .bin).ghw

$(WORKDIR) $(WAVESDIR):
	@mkdir $@

.import: $(RTL_SRC) $(TBS_SRC) | $(WORKDIR)
	@$(GHDL) -i $(GHDLFLAGS) $(RTL_SRC) $(TBS_SRC) | tee $@

.make: .import
	@$(GHDL) -m $(GHDLFLAGS) $(TOP_TB) | tee $@

ifdef WAVEFORM
GHDLXOPTS += --wave=$(WAVESDIR)/$(WAVEFORM)
# GHDLXOPTS += --fst=$(WAVESDIR)/$(WAVEFORM).fst
endif
.PHONY: simulation clean
simulation: .make | $(WAVESDIR)
	@$(GHDL) -r $(GHDLFLAGS) $(TOP_TB) $(GHDLXOPTS) -gPROGRAM=$(PROGRAM)

clean:
	@$(GHDL) clean --workdir=$(WORKDIR)
	@rm -rf .import .make $(WORKDIR) $(WAVESDIR)
