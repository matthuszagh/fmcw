set src_dir src
create_project top -in_memory -part xc7a15tftg256-1
read_verilog -sv $src_dir/top.v \
    $src_dir/async_fifo.v \
    $src_dir/ram.v \
    $src_dir/bin2gray.v \
    $src_dir/ff_sync.v \
    $src_dir/gray_ctr.v
read_xdc $src_dir/pinmap.xdc
synth_design -name top \
    -top top \
    -part xc7a15tftg256-1
opt_design
place_design
route_design
report_utilization
report_timing
write_bitstream -force top.bit
