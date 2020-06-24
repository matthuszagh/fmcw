CC		= clang
CFLAGS		= -O3 -march=native
DEBUG_FLAGS	= -O0 -g3
FTDI_CFLAGS	:= $(shell libftdi1-config --cflags)
LINKER_FLAGS	:= $(shell libftdi1-config --libs) -lm -lpthread

libdevice.a: device.o queue.o
	ar rcs $@ $^

device.o: device.c
	bear --append $(CC) $(CFLAGS) $(FTDI_CFLAGS) $(LINKER_FLAGS) -c device.c

queue.o: queue.c queue.h
	bear --append $(CC) $(CFLAGS) $(FTDI_CFLAGS) $(LINKER_FLAGS) -c device.c

device: device.c
	$(CC) $(CFLAGS) $(FTDI_CFLAGS) $(LINKER_FLAGS) device.c queue.c -o device

.PHONY: debug
debug: device.c
	rm -f device
	$(CC) $(DEBUG_FLAGS) $(FTDI_CFLAGS) $(LINKER_FLAGS) device.c queue.c -o device

.PHONY: valgrind
valgrind:
	rm -f device
	$(CC) $(DEBUG_FLAGS) $(FTDI_CFLAGS) device.c queue.c -o device $(LINKER_FLAGS)
	valgrind --leak-check=yes ./device
