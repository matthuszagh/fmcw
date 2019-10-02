set PART xc7a15tftg256-1
set LIBDIGITAL_PATH /home/matt/src/libdigital/libdigital/hdl

set FFT_DIR $LIBDIGITAL_PATH/fft/r22sdf/verilog/single/
set FIR_DIR $LIBDIGITAL_PATH/filters/fir/poly/verilog/120taps/1-channel/
set ADF4158_DIR $LIBDIGITAL_PATH/device_interfaces/adf4158
set MULT_ADD_DIR $LIBDIGITAL_PATH/dsp/multiply_add
set RAM_SINGLE_DIR $LIBDIGITAL_PATH/memory/ram/single_port
set RAM_DUAL_DIR $LIBDIGITAL_PATH/memory/ram/dual_port
set SHIFT_REG_DIR $LIBDIGITAL_PATH/memory/shift_reg

create_project top -in_memory -part $PART
read_verilog -sv top.v
read_xdc pinmap.xdc
synth_design -name top -top top -part $PART \
    -include_dirs "$FFT_DIR $FIR_DIR $ADF4158_DIR $MULT_ADD_DIR $RAM_SINGLE_DIR $RAM_DUAL_DIR $SHIFT_REG_DIR"
opt_design
place_design
route_design
report_utilization
report_timing
report_clocks
