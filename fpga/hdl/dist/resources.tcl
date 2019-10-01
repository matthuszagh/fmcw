read_verilog -sv top.v
read_xdc pinmap.xdc
synth_design -top top \
    -include_dirs {fir/ fft/} \
    -part xc7a15tftg256-1
report_utilization
report_timing
