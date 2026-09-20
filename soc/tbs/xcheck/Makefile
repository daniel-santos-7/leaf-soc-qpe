# Equivalence bench: the vendor Verilog model (ram.v, under Icarus) and the VHDL
# twin (soc/tbs/tsdn65lpa2048x16m8m.vhdl, under GHDL) are fed the same stimulus
# and their per-cycle QA/QB are diffed.
#
#   make            # generate stimulus, run both, diff
#   make CYCLES=20000 SEED=7
#
# Everything lands in build/; nothing here is part of the SoC simulation.

CYCLES ?= 5000
SEED   ?= 1

BUILD  = build
RAM_V  = ../../../ram.v
MACRO  = ../tsdn65lpa2048x16m8m.vhdl

GHDL      ?= ghdl
IVERILOG  ?= iverilog
VVP       ?= vvp

GHDLFLAGS = --workdir=$(BUILD) --ieee=synopsys

.PHONY: all clean
all: $(BUILD)/report

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/stimulus.txt: gen_stimulus.py | $(BUILD)
	cd $(BUILD) && python3 ../gen_stimulus.py $(CYCLES) $(SEED)

# +define+UNIT_DELAY keeps the vendor model in its functional flavour: the
# specify block, the path delays and the timing checks are all skipped.
$(BUILD)/tb_verilog: tb_macro.v $(RAM_V) | $(BUILD)
	$(IVERILOG) -g2005 -DUNIT_DELAY -o $@ tb_macro.v $(RAM_V)

$(BUILD)/out_verilog.txt: $(BUILD)/tb_verilog $(BUILD)/stimulus.txt
	cd $(BUILD) && $(VVP) tb_verilog

$(BUILD)/tb_vhdl: tb_macro.vhdl $(MACRO) | $(BUILD)
	$(GHDL) -a $(GHDLFLAGS) $(MACRO) tb_macro.vhdl
	$(GHDL) -e $(GHDLFLAGS) -o $@ tb_macro

$(BUILD)/out_vhdl.txt: $(BUILD)/tb_vhdl $(BUILD)/stimulus.txt
	cd $(BUILD) && ./tb_vhdl --ieee-asserts=disable

$(BUILD)/report: $(BUILD)/out_verilog.txt $(BUILD)/out_vhdl.txt
	@if diff -q $(BUILD)/out_verilog.txt $(BUILD)/out_vhdl.txt > /dev/null; then \
	    echo "EQUIVALENT: $$(wc -l < $(BUILD)/out_vhdl.txt) cycles match (seed $(SEED))"; \
	    touch $@; \
	else \
	    echo "MISMATCH (first 20 differing cycles):"; \
	    diff $(BUILD)/out_verilog.txt $(BUILD)/out_vhdl.txt | head -40; \
	    exit 1; \
	fi

clean:
	rm -rf $(BUILD)
