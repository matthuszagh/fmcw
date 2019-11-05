export
YOSYS_DIR	= yosys
TOP_MODULE_DIR	= $(abspath $(dir $(TOP_MODULE_SRC)))
# yosys doesn't like when the top module directory is also specified
# as an include directory.
VERILOG_INCS	:= $(filter-out -I$(TOP_MODULE_DIR),$(VERILOG_INCS))
VERILOG_SRCS    := $(filter-out $(TOP_MODULE_SRC),$(VERILOG_SRCS))

VIVADO_DIR	= vivado
VIVADO_INCS	= $(subst -I,,$(VERILOG_INCS))

OPENOCD_DIR	= openocd


.PHONY: prog
prog: pnr
	sudo openocd -f $(OPENOCD_DIR)/interface.cfg -f $(OPENOCD_DIR)/program_fpga.cfg

.PHONY: pnr
pnr: $(TOP_MODULE).bit

$(TOP_MODULE).bit: synth
	vivado -nolog -nojournal -mode batch -source $(VIVADO_DIR)/pnr.tcl

.PHONY: synth
synth: synth_xilinx

.PHONY: synth_xilinx
synth_xilinx: $(TOP_MODULE).edif

$(TOP_MODULE).edif: $(VERILOG_SRCS)
	vivado -nolog -nojournal -mode batch -source $(VIVADO_DIR)/synth.tcl

# $(TOP_MODULE).edif: $(TOP_MODULE).ilang $(YOSYS_DIR)/xilinx.tcl
# 	yosys $(YOSYS_DIR)/xilinx.tcl

$(TOP_MODULE).ilang: $(YOSYS_DIR)/synth.tcl $(VERILOG_SRCS) $(TOP_MODULE_SRC)
	yosys $(YOSYS_DIR)/synth.tcl

.PHONY: clean
clean::
	rm -f *.ilang
	rm -rf .Xil
