# options
USE_NMIGEN	= 0
LOG		= 1

# constants
GATEWARE_DIR	= gateware
SOFTWARE_DIR	= software

.PHONY: run
run: pc prog
ifeq ($(LOG), 1)
	./$(SOFTWARE_DIR)/read -t2 -l log.bin
else
	./$(SOFTWARE_DIR)/read -t60
endif

.PHONY: pc
pc:
	$(MAKE) -C $(SOFTWARE_DIR) read

.PHONY: prog
prog:
ifeq ($(USE_NMIGEN), 1)
	$(MAKE) -C $(GATEWARE_DIR)/nmigen prog
else
	$(MAKE) -C $(GATEWARE_DIR)/verilog prog
endif
