FTDI_DIR = ftdi
FPGA_DIR = fpga
PC_DIR = pc

all: ftdi_eeprom fpga run

run: | prog_fpga pc

pc:
	$(MAKE) collect -C $(PC_DIR)
	$(MAKE) analyze -C $(PC_DIR)

ftdi_eeprom:
	$(MAKE) -C $(FTDI_DIR)

prog_fpga:
	$(MAKE) prog_fpga -C $(FPGA_DIR)

fpga:
	$(MAKE) -C $(FPGA_DIR)

.PHONY: all run pc ftdi_eeprom prog_fpga fpga
