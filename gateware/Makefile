export

# source files
VERILOG_DIRS	:= $(shell pwd)

VERILOG_INCS	= $(addprefix -I,$(VERILOG_DIRS))
VERILOG_SRCS	:= $(shell find $(VERILOG_DIRS) -maxdepth 1 -name '*.v')

TOP_MODULE	= top
TOP_MODULE_SRC	:= $(realpath $(TOP_MODULE).v)

# Synthesis, place and route and formal verification
SCRIPT_DIR	:= $(realpath scripts)

# Testing
TEST_DIR	:= $(realpath test)

fft_roms	= roms/fft/s*.hex
fir_roms	= roms/fir/s*.hex
window_roms	= roms/window/s*.hex


$(fft_roms): scripts/fft.py
	cd scripts && ./fft.py

$(fir_roms): scripts/fir.py
	cd scripts && ./fir.py

$(window_roms): scripts/window.py
	cd scripts && ./window.py

.PHONY: test
test: test_cocotb

.PHONY: test_cocotb
test_cocotb:
	$(MAKE) -C $(TEST_DIR) cocotb

.PHONY: prog
prog: pnr
	$(MAKE) -C $(SCRIPT_DIR) prog

.PHONY: synth
synth: $(fft_roms) $(fir_roms) $(window_roms)
	$(MAKE) -C $(SCRIPT_DIR) synth

.PHONY: pnr
pnr: synth
	$(MAKE) -C $(SCRIPT_DIR) pnr

.PHONY: lint
lint:
	verilator $(VERILOG_INCS) \
		--lint-only \
		--Wall \
		--top-module $(TOP_MODULE) \
		$(TOP_MODULE_SRC)
