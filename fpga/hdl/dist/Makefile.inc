# vivado paths
VIVADO_SRC_PATH	:= -I/home/matt/src/vivado/2019_libs
UNIMACRO_PATH	:= $(VIVADO_SRC_PATH)/unimacro
UNISIMS_PATH	:= $(VIVADO_SRC_PATH)/unisims

# local paths
LIBDIGITAL_PATH := /home/matt/src/libdigital/libdigital/hdl
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
