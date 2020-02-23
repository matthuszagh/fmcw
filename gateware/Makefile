export

# source files
VERILOG_DIRS	:= $(shell pwd)

VERILOG_INCS	= $(addprefix -I,$(VERILOG_DIRS))
VERILOG_SRCS	:= $(shell find $(VERILOG_DIRS) -maxdepth 1 -name '*.v')

# TOP_MODULE	= top
TOP_MODULE_SRC	:= $(realpath top.v)

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

.PHONY: prog
prog: pnr
	$(MAKE) -C $(SCRIPT_DIR) prog

.PHONY: synth $(VERILOG_SRCS)
synth: $(fft_roms) $(fir_roms) $(window_roms)
	$(MAKE) -C $(SCRIPT_DIR) synth

.PHONY: pnr
pnr: synth
	$(MAKE) -C $(SCRIPT_DIR) pnr

# tests and formal
.PHONY: lint
lint:
	$(eval TOP_MODULE = top)
	verilator $(VERILOG_INCS) \
		--lint-only \
		--Wall \
		--top-module $(TOP_MODULE) \
		$(TOP_MODULE_SRC)

.PHONY: test
test: test_top test_fft test_fir test_ft245 test_async_fifo test_pll_sync_ctr test_shift_reg test_window

.PHONY: test_top
test_top:
	$(eval TOP = 1)
	$(eval TOP_MODULE = top)
	$(MAKE) -C $(TEST_DIR) cocotb

.PHONY: test_fft
test_fft:
	$(eval FFT = 1)
	$(eval TOP_MODULE = fft)
	$(MAKE) -C $(TEST_DIR) cocotb

.PHONY: test_fir
test_fir:
	$(eval FIR = 1)
	$(eval TOP_MODULE = fir)
	$(MAKE) -C $(TEST_DIR) cocotb

.PHONY: test_ft245
test_ft245:
	$(eval FT245 = 1)
	$(eval TOP_MODULE = ft245)
	$(MAKE) -C $(TEST_DIR) cocotb

.PHONY: test_async_fifo
test_async_fifo:
	$(eval ASYNC_FIFO = 1)
	$(eval TOP_MODULE = async_fifo)
	$(MAKE) -C $(TEST_DIR) cocotb

.PHONY: test_pll_sync_ctr
test_pll_sync_ctr:
	$(eval PLL_SYNC_CTR = 1)
	$(eval TOP_MODULE = pll_sync_ctr)
	$(MAKE) -C $(TEST_DIR) cocotb

.PHONY: test_shift_reg
test_shift_reg:
	$(eval SHIFT_REG = 1)
	$(eval TOP_MODULE = shift_reg)
	$(MAKE) -C $(TEST_DIR) cocotb

.PHONY: test_window
test_window:
	$(eval WINDOW = 1)
	$(eval TOP_MODULE = window)
	$(MAKE) -C $(TEST_DIR) cocotb

.PHONY: formal
formal: formal_async_fifo formal_dual_ff formal_pll_sync_ctr

.PHONY: formal_async_fifo
formal_async_fifo:
	$(eval TOP_MODULE = async_fifo)
	$(MAKE) -C $(SCRIPT_DIR) formal

.PHONY: formal_dual_ff
formal_dual_ff:
	$(eval TOP_MODULE = dual_ff)
	$(MAKE) -C $(SCRIPT_DIR) formal

.PHONY: formal_pll_sync_ctr
formal_pll_sync_ctr:
	$(eval TOP_MODULE = pll_sync_ctr)
	$(MAKE) -C $(SCRIPT_DIR) formal
