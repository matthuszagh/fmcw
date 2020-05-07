create_project $::env(TOP_MODULE) -in_memory -part xc7a15tftg256-1
read_verilog -sv ../$::env(TOP_MODULE).v $::env(VERILOG_SRCS)
read_xdc ../pinmap.xdc
synth_design -name $::env(TOP_MODULE) \
    -top $::env(TOP_MODULE) \
    -part xc7a15tftg256-1 \
    -include_dirs $::env(VIVADO_INCS) \
    -generic FIR_TAP_WIDTH=$::env(FIR_TAP_WIDTH) \
    -generic FIR_NORM_SHIFT=$::env(FIR_NORM_SHIFT) \
    -generic FIR_OUTPUT_WIDTH=$::env(FIR_OUTPUT_WIDTH) \
    -generic FFT_TWIDDLE_WIDTH=$::env(FFT_TWIDDLE_WIDTH)
opt_design
write_edif -force $::env(TOP_MODULE).edif
