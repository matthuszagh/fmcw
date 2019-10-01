create_project top -in_memory -part xc7a15tftg256-1
read_verilog -sv top.v
read_xdc pinmap.xdc
synth_design -name top -top top -part xc7a15tftg256-1 -include_dirs {fir/ fft/}
opt_design
place_design
route_design
report_utilization
report_timing
report_clocks
