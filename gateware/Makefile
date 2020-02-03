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

fft_roms	= gateware/roms/fft/s*.hex
fir_roms	= gateware/roms/fir/s*.hex
window_roms	= gateware/roms/window/s*.hex


$(fft_roms): gateware/scripts/fft.py
	cd gateware/scripts && ./fft.py

$(fir_roms): gateware/scripts/fir.py
	cd gateware/scripts && ./fir.py

$(window_roms): gateware/scripts/window.py
	cd gateware/scripts && ./window.py

.PHONY: test
test: test_cocotb

.PHONY: test_cocotb
test_cocotb:
	$(MAKE) -C $(TEST_DIR) cocotb

.PHONY: prog
prog:
	$(MAKE) -C $(SCRIPT_DIR) prog

.PHONY: synth
synth: $(fft_roms) $(fir_roms) $(window_roms)
	$(MAKE) -C $(SCRIPT_DIR) synth

.PHONY: pnr
pnr:
	$(MAKE) -C $(SCRIPT_DIR) pnr

.PHONY: lint
lint:
	verilator $(VERILOG_INCS) \
		--lint-only \
		--Wall \
		--top-module $(TOP_MODULE) \
		$(TOP_MODULE_SRC)
