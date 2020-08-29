../../$(TOP_MODULE).edif: synth.tcl $(VERILOG_SRCS) $(TOP_MODULE_SRC)
	yosys synth.tcl

formal:
	sby -f formal.sby
