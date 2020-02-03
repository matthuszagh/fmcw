export

GATEWARE_DIR	= gateware
SOFTWARE_DIR	= software

DEBUG		= 0

.PHONY: run
run: bitstream prog
	$(MAKE) -C $(SOFTWARE_DIR) acquire

.PHONY: prog
prog: bitstream
	$(MAKE) -C $(GATEWARE_DIR) prog

.PHONY: bitstream
bitstream:
	$(MAKE) -C $(GATEWARE_DIR) pnr
