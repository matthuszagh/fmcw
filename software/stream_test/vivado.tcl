create_project top -in_memory -part xc7a15tftg256-1
read_verilog -sv top.v fifo.v ram.v bin2gray.v ff_sync.v gray_ctr.v
read_xdc pinmap.xdc
synth_design -name top \
    -top top \
    -part xc7a15tftg256-1
opt_design
place_design
route_design
report_utilization
report_timing
write_bitstream -force top.bit
