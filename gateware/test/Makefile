export

# Cocotb requires some specific enviro variable definitions. Provide
# them here.

# cocotb places build files relative to this directory.
USER_DIR		= $(TEST_DIR)/cocotb
TOPLEVEL		= $(TOP_MODULE) # top-level verilog module
MODULE			= test_$(TOP_MODULE) # name of the python test module
COCOTB_PY_DIR		= $(USER_DIR)
SIM			= icarus
# places the simulation executable inside the build directory.
SIM_BUILD		= $(USER_DIR)/build
# place simulation results file in build dir
COCOTB_RESULTS_FILE	= $(SIM_BUILD)/results.xml
include $(shell cocotb-config --makefiles)/Makefile.inc
include $(shell cocotb-config --makefiles)/Makefile.sim
VERILOG_SOURCES		= $(VERILOG_SRCS)
# Cocotb has trouble finding verilog files. Pass them directly to
# the simulator instead.
COMPILE_ARGS		= $(addprefix -I,$(VERILOG_DIRS))
# Parameters must be set through the simulator.
# EXTRA_ARGS		= "-PWIDTH=64 -PSIZE=1024"

ICARUS_BUILD_DIR	:= icarus/build

# TODO make clean is inefficient. should be better way to make this work
.PHONY: cocotb
cocotb:
	$(MAKE) clean
	$(MAKE) sim
