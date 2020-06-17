# options
USE_NMIGEN	= 0
LOG		= 0

# constants
GATEWARE_DIR	= gateware
SOFTWARE_DIR	= software

.PHONY: run
run: pc prog
ifeq ($(LOG), 1)
	./$(SOFTWARE_DIR)/fmcw -t2 -l log.bin
else
	./$(SOFTWARE_DIR)/fmcw -t360
endif

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
