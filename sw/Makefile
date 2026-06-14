COREMARK_DIR = coremark
COREMARK_BIN = sw/$(COREMARK_DIR)/coremark.bin
LOG_DIR      = logs
LOG_FILE     = $(LOG_DIR)/coremark-$(shell date +%Y%m%d-%H%M%S).log
LOG_LATEST   = $(LOG_DIR)/coremark-latest.log

.PHONY: all coremark run clean

all: coremark run

coremark:
	$(MAKE) -C $(COREMARK_DIR) CORE_DEBUG=1

run: coremark
	@mkdir -p $(LOG_DIR)
	$(MAKE) -C .. run PROGRAM=$(COREMARK_BIN) 2>&1 | tee $(LOG_FILE)
	@ln -sf $(notdir $(LOG_FILE)) $(LOG_LATEST)
	@echo "Log saved: $(LOG_FILE)"

.PHONY: run-quick
run-quick:
	@mkdir -p $(LOG_DIR)
	$(MAKE) -C .. run PROGRAM=$(COREMARK_BIN) GHDLXOPTS="--ieee-asserts=disable --stop-time=1500ms" 2>&1 | tee $(LOG_FILE)
	@ln -sf $(notdir $(LOG_FILE)) $(LOG_LATEST)
	@echo "Log saved: $(LOG_FILE) (quick mode)"

clean:
	$(MAKE) -C $(COREMARK_DIR) clean
	rm -rf $(LOG_DIR)
