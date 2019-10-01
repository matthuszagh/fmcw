include Makefile.inc

SYNTHESIS_TOOL  = vivado

SOURCES		= top.v adc.v adf4158.v mult_add.v ram_single_18k.v ram_tdp_18k.v shift_reg.v usb.v fft/*.v fir/*.v
CONSTRAINTS	= pinmap.xdc

FTDI_CFLAGS    := $(shell libftdi1-config --cflags)
COMPILER	= clang
CFLAGS		= -O0
LINKER_FLAGS   := $(shell libftdi1-config --libs)
OPENOCD_DIR     = openocd

read: prog read.c
	sudo rmmod ftdi_sio
	$(COMPILER) $(CFLAGS) $(FTDI_CFLAGS) read.c -o read $(LINKER_FLAGS)
	sudo ./read read_taps.txt

prog: bitstream
	sudo openocd -f $(OPENOCD_DIR)/interface.cfg -f $(OPENOCD_DIR)/program_fpga.cfg

bitstream: top.bit

top.bit: $(SOURCES) $(CONSTRAINTS) synth.tcl yosys_synth.ys
ifeq ($(SYNTHESIS_TOOL),yosys)
	yosys yosys_synth.ys
	vivado -nolog -nojournal -mode batch -source vivado_backend.tcl
else
	vivado -nolog -nojournal -mode batch -source synth.tcl
endif

timing: $(SOURCES) timing.tcl
	vivado -nolog -nojournal -mode batch -source timing.tcl

test:
	iverilog $(INCLUDE_DIRS) -DTOP_SIMULATE top.v -o tb/top_tb
	./tb/top_tb
	gtkwave tb/top_tb.vcd

resources:
	vivado -nolog -nojournal -mode batch -source resources.tcl

.PHONY: resources bitstream
