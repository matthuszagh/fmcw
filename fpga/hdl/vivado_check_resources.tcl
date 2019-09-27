add_files top.v
read_xdc pinmap.xdc
synth_design -top top -part xc7a15tftg256-1 -include_dirs {fir/ fft/ usb/ adc/ adf4158/ dsp/}
report_utilization
