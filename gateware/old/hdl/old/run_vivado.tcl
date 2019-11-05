create_project top -in_memory -part xc7a15tftg256-1
# create_project top -in_memory -part xc7a50tftg256-1
add_files top.v
read_xdc pinmap.xdc
synth_design -name top -top top -part xc7a15tftg256-1 -include_dirs {fir/ fft/ usb/ adc/ adf4158/ dsp/}
# synth_design -name top -top top -part xc7a50tftg256-1 -include_dirs {fir/ fft/ usb/ adc/ adf4158/}
opt_design
place_design
route_design
report_utilization
report_timing
write_bitstream -force top.bit
