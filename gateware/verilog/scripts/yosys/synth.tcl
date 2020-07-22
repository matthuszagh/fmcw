yosys -import
read_verilog -sv $::env(VERILOG_INCS) $::env(TOP_MODULE_SRC)
hierarchy
procs;;
synth_xilinx -top $::env(TOP_MODULE) -edif ../../top.edif
