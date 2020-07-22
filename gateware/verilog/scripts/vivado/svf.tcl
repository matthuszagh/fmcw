open_hw
create_hw_target svf_target
open_hw_target [get_hw_targets -regexp .*/svf_target]

# set FPGA device
set fpga_device [create_hw_device -part xc7a15t]

# set FPGA bitstream
set_property PROGRAM.FILE {top.bit} $fpga_device

# write bitstream to SVF file
program_hw_devices -force -svf_file {top.svf} $fpga_device

# # tell SVF to load bitstream to external SPI flash in addition to FPGA
# set flash_device [create_hw_cfgmem -hw_device $fpga_device n25q32-3.3v-spi-x1_x2_x4]
# set_property PROGRAM.FILES {flash.bin} $flash_device
# set_property PROGRAM.CFG_PROGRAM 1 $flash_device
# # set_property PROGRAM.VERIFY 1 $flash_device
# # program_hw_cfgmem $flash_device
# program_hw_cfgmem -force -svf_file {flash.svf} $flash_device
