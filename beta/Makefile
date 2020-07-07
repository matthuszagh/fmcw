# options
USE_NMIGEN	= 0
LOG		= 0

# constants
GATEWARE_DIR	= gateware
SOFTWARE_DIR	= software

.PHONY: run
run: prog
	$(MAKE) -C $(SOFTWARE_DIR) run

.PHONY: pc
pc:
	$(MAKE) -C $(SOFTWARE_DIR) fmcw

.PHONY: prog
prog:
ifeq ($(USE_NMIGEN), 1)
	$(MAKE) -C $(GATEWARE_DIR)/nmigen prog
else
	$(MAKE) -C $(GATEWARE_DIR)/verilog prog
endif
