export

GATEWARE_DIR	= gateware
SOFTWARE_DIR	= software

DEBUG		= 0


.PHONY: run
run: prog
	# $(eval include $(GATEWARE_DIR)/scripts/env.sh)
	$(MAKE) -C $(SOFTWARE_DIR) acquire

.PHONY: prog
prog:
	$(MAKE) -C $(GATEWARE_DIR) prog

.PHONY: bitstream
bitstream:
	$(MAKE) -C $(GATEWARE_DIR) pnr


# tests and formal verification
.PHONY: test
test:
	$(MAKE) -C $(GATEWARE_DIR) test

.PHONY: formal
formal:
	$(MAKE) -C $(GATEWARE_DIR) formal
