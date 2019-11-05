LIBFTDI_DIR = /home/matt/src/libftdi/build/examples
CONF_FILE = eeprom.conf

all:
	@echo "EEPROM before programming:"
	$(MAKE) read
	@echo "EEPROM after programming:"
	$(MAKE) prog
	$(MAKE) read

prog:
	ftdi_eeprom --flash-eeprom $(CONF_FILE)

read:
	$(LIBFTDI_DIR)/eeprom

rmmod:
	modprobe -qr ftdi_sio

.PHONY: all prog read rmmod
