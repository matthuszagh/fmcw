yosys -import
eval read_verilog -sv $::env(VERILOG_INCS) $::env(TOP_MODULE_SRC)
hierarchy
procs;;
write_ilang $::env(TOP_MODULE).ilang
