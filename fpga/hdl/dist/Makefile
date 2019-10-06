include Makefile.inc

# Currently, only vivado is supported although future support is
# planned for yosys.
SYNTHESIS_TOOL  = vivado

SOURCES		= top.v \
		  adc.v \
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
