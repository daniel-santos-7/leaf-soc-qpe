# VHDL simulator
GHDL = ghdl
GHDLFLAGS = --workdir=$(WORKDIR) --ieee=synopsys
GHDLXOPTS = --stop-time=1000ms

WORKDIR  = work
WAVESDIR = waves

RTL_SRC  = $(wildcard ./rtl/*.vhdl)
TBS_SRC  = $(wildcard ./tbs/*.vhdl)

TOP_TB = uart_tb

$(WORKDIR) $(WAVESDIR):
	@mkdir $@

.import: $(RTL_SRC) $(TBS_SRC) | $(WORKDIR)
	@$(GHDL) -i $(GHDLFLAGS) $(RTL_SRC) $(TBS_SRC) | tee $@

.make: .import
	@$(GHDL) -m $(GHDLFLAGS) $(TOP_TB) | tee $@

$(WAVESDIR)/$(TOP_TB).ghw: .make | $(WAVESDIR)
	@$(GHDL) -r $(GHDLFLAGS) $(TOP_TB) $(GHDLXOPTS) --wave=$@

.PHONY: simulation clean
simulation: .make
	@$(GHDL) -r $(GHDLFLAGS) $(TOP_TB) $(GHDLXOPTS)

clean:
	@$(GHDL) clean --workdir=$(WORKDIR)
	@rm -rf .import .make $(WORKDIR) $(WAVESDIR)
