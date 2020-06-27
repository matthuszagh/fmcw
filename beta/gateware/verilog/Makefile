export

VERILOG_DIRS	:= $(realpath src)
VERILOG_INCS	= $(addprefix -I,$(VERILOG_DIRS))

SCRIPT_DIR	= scripts
YOSYS_SCRIPT	= $(SCRIPT_DIR)/yosys
VERILOG_SRCS	:= $(shell find $(VERILOG_DIRS) -maxdepth 1 -name '*.v')

TEST_DIR	:= $(realpath test)

TOP_MODULE	= top
TOP_MODULE_SRC	:= $(realpath src/top.v)

.PHONY: prog
prog: top.svf bscan_spi_xc7a15t.bit scripts/openocd/*
	openocd -s scripts/openocd -f openocd.cfg
	# openocd -s scripts/openocd -f interface.cfg -f program_flash.cfg
	# openocd -s scripts/openocd -f interface.cfg -f program_fpga.cfg -f program_flash.cfg -f openocd.cfg

top.svf: top.bit scripts/vivado/svf.tcl
	vivado -nolog -nojournal -mode batch -source scripts/vivado/svf.tcl
	# sh scripts/winbond_flash.sh

bscan_spi_xc7a15t.bit: scripts/xilinx_bscan_spi.py
	python scripts/xilinx_bscan_spi.py xc7a15t
	cp build/bscan_spi_xc7a15t.bit .

flash.bin: top.bit
	vivado -nolog -nojournal -mode batch -source scripts/vivado/flash_bitstream.tcl

top.bit: src/* env.sh
	vivado -nolog -nojournal -mode batch -source scripts/vivado/synth.tcl

env.sh: $(SCRIPT_DIR)/roms.py $(SCRIPT_DIR)/fir.py $(SCRIPT_DIR)/fft.py $(SCRIPT_DIR)/window.py
	python $(SCRIPT_DIR)/roms.py

.PHONY: lint
lint:
	$(eval TOP_MODULE = top)
	verilator $(VERILOG_INCS) \
		--lint-only \
		--Wall \
		--top-module $(TOP_MODULE) \
		$(TOP_MODULE_SRC)

# cocotb simulations
.PHONY: test_fft
test_fft:
	$(eval TOP_MODULE = fft)
	$(MAKE) -C $(TEST_DIR) cocotb

# traditional testbenches
.PHONY: sim
sim:
	iverilog -DTOP_SIMULATE=1 -s top_tb src/*.v -Isrc && ./a.out

.PHONY: sim_adf4158
sim_adf4158:
	iverilog -DADF4158_SIMULATE=1 -s adf4158_tb src/adf4158.v && ./a.out

.PHONY: sim_ff_sync
sim_ff_sync:
	iverilog -DFF_SYNC_SIMULATE=1 -s ff_sync_tb src/ff_sync.v && ./a.out

# formal verification
.PHONY: formal_dual_ff
formal_dual_ff:
	$(eval TOP_MODULE = dual_ff)
	$(MAKE) -C $(YOSYS_SCRIPT) formal

.PHONY: formal_pll_sync_ctr
formal_pll_sync_ctr:
	$(eval TOP_MODULE = pll_sync_ctr)
	$(MAKE) -C $(YOSYS_SCRIPT) formal

.PHONY: clean
clean:
	rm -f a.out
	rm -f flash.prm
	rm -f usage_statistics_webtalk*
	rm -rf .Xil
