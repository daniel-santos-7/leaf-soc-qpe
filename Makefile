# leaf project

# VHDL simulator
GHDL = ghdl
GHDLFLAGS = --workdir=$(WORKDIR) --ieee=synopsys
GHDLXOPTS = --ieee-asserts=disable --max-stack-alloc=0 --stop-time=100us

WORKDIR  = work
WAVESDIR = waves

CPU_RTL  = $(wildcard ./ips/cpu/rtl/*.vhdl)
CPU_TBS  = $(wildcard ./ips/cpu/tbs/*.vhdl)
UART_RTL = $(wildcard ./ips/uart/rtl/*.vhdl)
UART_TBS = $(wildcard ./ips/uart/tbs/*.vhdl)
SOC_RTL  = $(wildcard ./soc/rtl/*.vhdl)
SOC_TBS  = $(wildcard ./soc/tbs/*.vhdl)

RTL_SRC  = $(CPU_RTL) $(UART_RTL) $(SOC_RTL)
TBS_SRC  = $(CPU_TBS) $(UART_TBS) $(SOC_TBS)

TOP_TB = leaf_soc_tb

PROGRAM ?= ./sw/c/hello_world/hello_world.bin

$(WORKDIR) $(WAVESDIR):
	mkdir $@

.import: $(RTL_SRC) $(TBS_SRC) | $(WORKDIR)
	$(GHDL) -i $(GHDLFLAGS) $(RTL_SRC) $(TBS_SRC) | tee $@

.make: .import
	$(GHDL) -m $(GHDLFLAGS) $(TOP_TB) | tee $@

$(WAVESDIR)/$(TOP_TB).ghw: .make | $(WAVESDIR)
	$(GHDL) -r $(GHDLFLAGS) $(TOP_TB) $(GHDLXOPTS) -gPROGRAM=$(PROGRAM) --wave=$@

.PHONY: run clean
run: .make
	$(GHDL) -r $(GHDLFLAGS) $(TOP_TB) $(GHDLXOPTS) -gPROGRAM=$(PROGRAM)

clean:
	$(GHDL) clean --workdir=$(WORKDIR)
	rm -rf .import .make $(WORKDIR) $(WAVESDIR)
