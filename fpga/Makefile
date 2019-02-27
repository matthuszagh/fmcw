PROJ      = top
DEVICE    = xc7a15tftg256-1
FILES = hdl/*
OPENOCD_DIR = openocd

all: | synth vivado prog_fpga

synth:
	yosys run_yosys.ys

vivado:
	vivado -nolog -nojournal -mode batch -source run_vivado.tcl

prog_fpga:
	openocd -f $(OPENOCD_DIR)/interface.cfg -f $(OPENOCD_DIR)/program_fpga.cfg

prog_flash:
	openocd -f $(OPENOCD_DIR)/interface.cfg -f $(OPENOCD_DIR)/program_flash.cfg

clean:
	rm -f *.edif
	rm -f *.log
	rm -f usage_statistics*

.PHONY: all synth vivado clean prog
