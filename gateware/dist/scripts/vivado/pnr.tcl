read_xdc ../pinmap.xdc
read_edif $::env(TOP_MODULE).edif
link_design -part xc7a15tftg256-1 -top $::env(TOP_MODULE)
opt_design
place_design
route_design
report_utilization
report_timing
write_bitstream -force $::env(TOP_MODULE).bit
