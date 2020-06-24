CC 		= clang
CSRC_DIR 	= src
FTDI_CFLAGS	:= $(shell libftdi1-config --cflags)
LINKER_FLAGS	:= $(shell libftdi1-config --libs) -lm -lpthread

.PHONY: run
run: device.so
	./fmcw.py

device.so: libdevice device.c
	$(CC) -shared -pthread -fPIC -O3 -Isrc/ \
		$(FTDI_CFLAGS) \
		$(shell pkg-config --cflags python) \
		-o device.so device.c src/device.c \
		$(LINKER_FLAGS)

device.c: device.pyx cdevice.pxd
	cython device.pyx cdevice.pxd

.PHONY: device
device: setup.py device.pyx cdevice.pxd libdevice
	rm -f device.cpython* device.c
	python setup.py build_ext -i

.PHONY: libdevice
libdevice:
	$(MAKE) -C $(CSRC_DIR) libdevice.a
