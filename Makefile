export

GATEWARE_DIR	= gateware
DIST_DIR	= $(GATEWARE_DIR)/dist
SOFTWARE_DIR	= software

DEBUG		= 0

.PHONY: run
run: run_dist

.PHONY: run_dist
run_dist: dist_bitstream dist_prog
	$(MAKE) -C $(SOFTWARE_DIR) acquire

.PHONY: dist_bitstream
dist_bitstream:
	$(MAKE) -C $(DIST_DIR) pnr

.PHONY: dist_prog
dist_prog: dist_bitstream
	$(MAKE) -C $(DIST_DIR) prog

# .PHONY: run_angle
# run_angle:



# FTDI_DIR = ftdi
# FPGA_DIR = fpga
# PC_DIR = pc

# all: ftdi_eeprom fpga run

# run: | prog_fpga pc

# pc:
# 	$(MAKE) collect -C $(PC_DIR)
# 	$(MAKE) analyze -C $(PC_DIR)

# ftdi_eeprom:
# 	$(MAKE) -C $(FTDI_DIR)

# prog_fpga:
# 	$(MAKE) prog_fpga -C $(FPGA_DIR)

# fpga:
# 	$(MAKE) -C $(FPGA_DIR)

# .PHONY: all run pc ftdi_eeprom prog_fpga fpga
