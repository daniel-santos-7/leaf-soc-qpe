COREMARK_DIR  = coremark
COREMARK_BIN  = sw/$(COREMARK_DIR)/coremark.bin
CORE_DEBUG   ?= 1
SW_ITERATIONS ?= 1000
LOG_DIR       = logs
LOG_FILE      = $(LOG_DIR)/coremark-$(shell date +%Y%m%d-%H%M%S).log
LOG_LATEST    = $(LOG_DIR)/coremark-latest.log

.PHONY: all coremark run run-quick clean upload monitor

all: coremark run

coremark:
	$(MAKE) -C $(COREMARK_DIR) CORE_DEBUG=$(CORE_DEBUG) SW_ITERATIONS=$(SW_ITERATIONS)

run: coremark
	@mkdir -p $(LOG_DIR)
	$(MAKE) -C .. run PROGRAM=$(COREMARK_BIN) 2>&1 | tee $(LOG_FILE)
	@ln -sf $(notdir $(LOG_FILE)) $(LOG_LATEST)
	@echo "Log saved: $(LOG_FILE)"

.PHONY: run-quick
run-quick: coremark
	@mkdir -p $(LOG_DIR)
	$(MAKE) -C .. run PROGRAM=$(COREMARK_BIN) RUN_CYCLES=75000000 2>&1 | tee $(LOG_FILE)
	@ln -sf $(notdir $(LOG_FILE)) $(LOG_LATEST)
	@echo "Log saved: $(LOG_FILE) (quick mode)"

clean:
	$(MAKE) -C $(COREMARK_DIR) clean
	rm -rf $(LOG_DIR)

BIN    ?= ./c/hello_world/hello_world.bin
PORT   ?= /dev/ttyUSB0
BAUD   ?= 115200

.PHONY: upload
upload: $(BIN)
	python3 utils/load_bin.py $(PORT) $(BIN) $(BAUD)

.PHONY: monitor
monitor:
	python3 -m serial.tools.miniterm $(PORT) $(BAUD) --eol LF
