export

# source files
VERILOG_DIRS	:= $(shell pwd)
VERILOG_DIRS	+= $(LIBDIGITAL_PATH)/memory/fifo
VERILOG_DIRS	+= $(LIBDIGITAL_PATH)/memory/ram
VERILOG_DIRS	+= $(LIBDIGITAL_PATH)/memory/shift_reg
VERILOG_DIRS	+= $(LIBDIGITAL_PATH)/devices/ltc2292
VERILOG_DIRS	+= $(LIBDIGITAL_PATH)/devices/adf4158
VERILOG_DIRS	+= $(LIBDIGITAL_PATH)/devices/ft2232h/ft245
VERILOG_DIRS	+= $(LIBDIGITAL_PATH)/filters/fir_poly
VERILOG_DIRS	+= $(LIBDIGITAL_PATH)/fft/r22sdf
VERILOG_DIRS	+= $(LIBDIGITAL_PATH)/error_detection

VERILOG_INCS	= $(addprefix -I,$(VERILOG_DIRS))
VERILOG_SRCS	:= $(shell find $(VERILOG_DIRS) -maxdepth 1 -name '*.v')

TOP_MODULE	= top
TOP_MODULE_SRC	:= $(realpath $(TOP_MODULE).v)

# Synthesis, place and route and formal verification
SCRIPT_DIR	:= $(realpath scripts)

# Testing
TEST_DIR	:= $(realpath test)


.PHONY: test
test: test_cocotb

.PHONY: test_cocotb
test_cocotb:
	$(MAKE) -C $(TEST_DIR) cocotb

.PHONY: prog
prog:
	$(MAKE) -C $(SCRIPT_DIR) prog

.PHONY: synth
synth:
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
