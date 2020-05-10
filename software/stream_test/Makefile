CC		= clang

CFLAGS	= -O3 -march=native
STRICT_CFLAGS	= $(CFLAGS) -Wall -Wextra -Wshadow -Wstrict-aliasing -ansi -pedantic -Werror
FTDI_CFLAGS	:= $(shell libftdi1-config --cflags)
LINKER_FLAGS	:= $(shell libftdi1-config --libs) -lm -lpthread

.PHONY: run
run: test
	./test -t 10 -l log.bin

test: prog test.c
	bear $(CC) $(CFLAGS) $(FTDI_CFLAGS) test.c -o test $(LINKER_FLAGS)

.PHONY: prog
prog: top.bit
	openocd -f interface.cfg -f program_fpga.cfg

top.bit: top.v async_fifo.v ram.v pinmap.xdc
	vivado -nolog -nojournal -mode batch -source vivado.tcl
