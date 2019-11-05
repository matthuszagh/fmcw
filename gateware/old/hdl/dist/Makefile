# vivado paths
UNIMACRO_PATH	:= $(VIVADO_SRC_PATH)/unimacro
UNISIMS_PATH	:= $(VIVADO_SRC_PATH)/unisims

# local paths
FFT_DIR         := $(LIBDIGITAL_PATH)/fft/r22sdf/verilog/single
FIR_DIR         := $(LIBDIGITAL_PATH)/filters/fir/poly/verilog/120taps/1-channel
ADF4158_DIR     := $(LIBDIGITAL_PATH)/device_interfaces/adf4158
LTC2292_DIR     := $(LIBDIGITAL_PATH)/device_interfaces/ltc2292
FT245_DIR       := $(LIBDIGITAL_PATH)/device_interfaces/ft2232h/ft245
ASYNC_FIFO_DIR  := $(LIBDIGITAL_PATH)/memory/fifo/async
MULT_ADD_DIR    := $(LIBDIGITAL_PATH)/dsp/multiply_add
RAM_DIR         := $(LIBDIGITAL_PATH)/memory/ram
RAM_SINGLE_DIR  := $(LIBDIGITAL_PATH)/memory/ram/single_port
RAM_DUAL_DIR    := $(LIBDIGITAL_PATH)/memory/ram/dual_port
SHIFT_REG_DIR   := $(LIBDIGITAL_PATH)/memory/shift_reg

LOCAL_DIRS      := $(FFT_DIR) \
                   $(FIR_DIR) \
                   $(ADF4158_DIR) \
		   $(LTC2292_DIR) \
                   $(FT245_DIR) \
		   $(ASYNC_FIFO_DIR) \
                   $(MULT_ADD_DIR) \
                   $(RAM_DIR) \
                   $(RAM_SINGLE_DIR) \
                   $(RAM_DUAL_DIR) \
                   $(SHIFT_REG_DIR)

INCLUDE_DIRS	:= $(VIVADO_SRC_PATH) $(UNIMACRO_PATH) $(UNISIMS_PATH) $(LOCAL_DIRS)


# Currently, only vivado is supported although future support is
# planned for yosys.
SYNTHESIS_TOOL  = vivado

SOURCES		= $(shell find . $(INCLUDE_DIRS) -name '*.v')

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

.PHONY: prog
prog: bitstream
	sudo openocd -f $(OPENOCD_DIR)/interface.cfg -f $(OPENOCD_DIR)/program_fpga.cfg

.PHONY: bitstream
bitstream: top.bit

top.bit: $(SOURCES) $(CONSTRAINTS) $(VIVADO_DIR)/synth.tcl yosys_synth.ys
ifeq ($(SYNTHESIS_TOOL),yosys)
	yosys yosys_synth.ys
	vivado -nolog -nojournal -mode batch -source $(VIVADO_DIR)/vivado_backend.tcl
else
	vivado -nolog -nojournal -mode batch -source $(VIVADO_DIR)/synth.tcl
endif

.PHONY: timing
timing: $(SOURCES) $(VIVADO_DIR)/timing.tcl
	vivado -nolog -nojournal -mode batch -source $(VIVADO_DIR)/timing.tcl

.PHONY: lint
lint: top.v
	verilator $(addprefix -I,$(INCLUDE_DIRS)) --bbox-sys --bbox-unsup --lint-only --Wall top.v

.PHONY: test
test:
	iverilog $(addprefix -I,$(INCLUDE_DIRS)) -DTOP_SIMULATE top.v -o tb/top_tb
	./tb/top_tb
	gtkwave tb/top_tb.vcd

.PHONY: resources
resources:
	vivado -nolog -nojournal -mode batch -source $(VIVADO_DIR)/resources.tcl
