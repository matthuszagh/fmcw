read_xdc hdl/pinmap.xdc
read_edif top.edif
link_design -part xc7a15tftg256-1 -top top
opt_design
place_design
route_design
report_utilization
report_timing
write_bitstream -force top.bit
