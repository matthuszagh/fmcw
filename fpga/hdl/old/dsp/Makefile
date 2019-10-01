check_resources:
	vivado -nolog -nojournal -mode batch -source run_vivado.tcl

tb:
	iverilog dsp.v -o dsp_tb
	./dsp_tb
	gtkwave dsp.vcd
