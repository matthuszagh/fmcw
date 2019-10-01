# vivado paths
VIVADO_SRC_PATH	:= -I/home/matt/src/vivado/2019_libs
UNIMACRO_PATH	:= $(VIVADO_SRC_PATH)/unimacro
UNISIMS_PATH	:= $(VIVADO_SRC_PATH)/unisims

# local paths
LOCAL_DIRS      := -Ifft -Ifir

INCLUDE_DIRS	:= $(VIVADO_SRC_PATH) $(UNIMACRO_PATH) $(UNISIMS_PATH) $(LOCAL_DIRS)
