.PHONY: prog
prog: top.bit scripts/interface.cfg scripts/program_fpga.cfg
	openocd -f scripts/interface.cfg -f scripts/program_fpga.cfg

top.bit: src/*
	vivado -nolog -nojournal -mode batch -source scripts/vivado.tcl

.PHONY: simulate
simulate:
	iverilog -DTOP_SIMULATE=1 -s top_tb src/*.v -Isrc && ./a.out
