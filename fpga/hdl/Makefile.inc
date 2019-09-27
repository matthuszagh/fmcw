HDL_ROOT        = $(shell git rev-parse --show-toplevel)/fpga/hdl

# vivado paths
VIVADO_SRC_PATH	:= -I/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src
UNIMACRO_PATH	:= $(VIVADO_SRC_PATH)/unimacro
UNISIMS_PATH	:= $(VIVADO_SRC_PATH)/unisims

# local dirs
LOCAL_INCLUDES	:= -I$(HDL_ROOT)/dsp -I$(HDL_ROOT)/fft -I$(HDL_ROOT)/adf4158 -I$(HDL_ROOT)/adc -I$(HDL_ROOT)/usb
INCLUDE_DIRS	:= $(LOCAL_INCLUDES) $(VIVADO_SRC_PATH) $(UNIMACRO_PATH) $(UNISIMS_PATH)

# FIR taps files
FILE_TAPS0_1	=	"$(HDL_ROOT)/fir/taps/taps0_1.hex"
FILE_TAPS2_3	=	"$(HDL_ROOT)/fir/taps/taps2_3.hex"
FILE_TAPS4_5	=	"$(HDL_ROOT)/fir/taps/taps4_5.hex"
FILE_TAPS6_7	=	"$(HDL_ROOT)/fir/taps/taps6_7.hex"
FILE_TAPS8_9	=	"$(HDL_ROOT)/fir/taps/taps8_9.hex"
FILE_TAPS10_11	=	"$(HDL_ROOT)/fir/taps/taps10_11.hex"
FILE_TAPS12_13	=	"$(HDL_ROOT)/fir/taps/taps12_13.hex"
FILE_TAPS14_15	=	"$(HDL_ROOT)/fir/taps/taps14_15.hex"
FILE_TAPS16_17	=	"$(HDL_ROOT)/fir/taps/taps16_17.hex"
FILE_TAPS18_19	=	"$(HDL_ROOT)/fir/taps/taps18_19.hex"
