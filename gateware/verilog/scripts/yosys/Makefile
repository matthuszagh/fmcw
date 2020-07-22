../../$(TOP_MODULE).edif: synth.tcl $(VERILOG_SRCS) $(TOP_MODULE_SRC)
	yosys synth.tcl

.PHONY: formal
formal:
	sby -f formal.sby
