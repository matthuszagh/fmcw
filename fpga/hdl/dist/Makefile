# vivado paths
VIVADO_SRC_PATH	:= -I/home/matt/src/vivado/2019_libs
UNIMACRO_PATH	:= $(VIVADO_SRC_PATH)/unimacro
UNISIMS_PATH	:= $(VIVADO_SRC_PATH)/unisims

# local paths
FFT_DIR         := $(LIBDIGITAL_PATH)/fft/r22sdf/verilog/single
FIR_DIR         := $(LIBDIGITAL_PATH)/filters/fir/poly/verilog/120taps/1-channel
ADF4158_DIR     := $(LIBDIGITAL_PATH)/device_interfaces/adf4158
LTC2292_DIR     := $(LIBDIGITAL_PATH)/device_interfaces/ltc2292
MULT_ADD_DIR    := $(LIBDIGITAL_PATH)/dsp/multiply_add
RAM_SINGLE_DIR  := $(LIBDIGITAL_PATH)/memory/ram/single_port
RAM_DUAL_DIR    := $(LIBDIGITAL_PATH)/memory/ram/dual_port
SHIFT_REG_DIR   := $(LIBDIGITAL_PATH)/memory/shift_reg

LOCAL_DIRS      := -I$(FFT_DIR) \
                   -I$(FIR_DIR) \
                   -I$(ADF4158_DIR) \
                   -I$(MULT_ADD_DIR) \
                   -I$(RAM_SINGLE_DIR) \
                   -I$(RAM_DUAL_DIR) \
                   -I$(SHIFT_REG_DIR)

INCLUDE_DIRS	:= $(VIVADO_SRC_PATH) $(UNIMACRO_PATH) $(UNISIMS_PATH) $(LOCAL_DIRS)


# Currently, only vivado is supported although future support is
# planned for yosys.
SYNTHESIS_TOOL  = vivado

SOURCES		= top.v \
		  usb.v \
		  $(ADF4158_DIR)/adf4158.v \
		  $(LTC2292_DIR)/ltc2292.v \
	 	  $(MULT_ADD_DIR)/mult_add.v \
		  $(RAM_SINGLE_DIR)/ram_single_18k.v \
		  $(RAM_DUAL_DIR)/ram_tdp_18k.v \
		  $(SHIFT_REG_DIR)/shift_reg.v \
		  $(FFT_DIR)/*.v \
		  $(FIR_DIR)/*.v

CONSTRAINTS	= pinmap.xdc

FTDI_CFLAGS    := $(shell libftdi1-config --cflags)
LINKER_FLAGS   := $(shell libftdi1-config --libs)
COMPILER	= clang
CFLAGS		= -O0
OPENOCD_DIR     = openocd
VIVADO_DIR      = vivado

read: prog read.c
	sudo rmmod ftdi_sio
	$(COMPILER) $(CFLAGS) $(FTDI_CFLAGS) read.c -o read $(LINKER_FLAGS)
	sudo ./read read.bin

prog: bitstream
	sudo openocd -f $(OPENOCD_DIR)/interface.cfg -f $(OPENOCD_DIR)/program_fpga.cfg

bitstream: top.bit

top.bit: $(SOURCES) $(CONSTRAINTS) $(VIVADO_DIR)/synth.tcl yosys_synth.ys
ifeq ($(SYNTHESIS_TOOL),yosys)
	yosys yosys_synth.ys
	vivado -nolog -nojournal -mode batch -source $(VIVADO_DIR)/vivado_backend.tcl
else
	vivado -nolog -nojournal -mode batch -source $(VIVADO_DIR)/synth.tcl
endif

timing: $(SOURCES) $(VIVADO_DIR)/timing.tcl
	vivado -nolog -nojournal -mode batch -source $(VIVADO_DIR)/timing.tcl

test:
	iverilog $(INCLUDE_DIRS) -DTOP_SIMULATE top.v -o tb/top_tb
	./tb/top_tb
	gtkwave tb/top_tb.vcd

resources:
	vivado -nolog -nojournal -mode batch -source $(VIVADO_DIR)/resources.tcl

.PHONY: resources bitstream test timing prog
