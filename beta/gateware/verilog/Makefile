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

top.bit: src/*
	vivado -nolog -nojournal -mode batch -source scripts/vivado/synth.tcl

.PHONY: sim
sim:
	iverilog -DTOP_SIMULATE=1 -s top_tb src/*.v -Isrc && ./a.out

.PHONY: sim_adf4158
sim_adf4158:
	iverilog -DADF4158_SIMULATE=1 -s adf4158_tb src/adf4158.v && ./a.out

.PHONY: clean
clean:
	rm -f a.out
	rm -f flash.prm
	rm -f usage_statistics_webtalk*
	rm -rf .Xil
