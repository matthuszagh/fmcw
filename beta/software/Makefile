CC		= clang

CFLAGS		= -O3 -march=native
DEBUG_FLAGS     = -O0 -g
STRICT_CFLAGS	= $(CFLAGS) -Wall -Wextra -Wshadow -Wstrict-aliasing -ansi -pedantic -Werror
FTDI_CFLAGS	:= $(shell libftdi1-config --cflags)
LINKER_FLAGS	:= $(shell libftdi1-config --libs) -lm -lpthread

fmcw: fmcw.c
	bear $(CC) $(CFLAGS) $(FTDI_CFLAGS) fmcw.c -o fmcw $(LINKER_FLAGS)

.PHONY: debug
debug: fmcw.c
	$(CC) $(DEBUG_FLAGS) $(FTDI_CFLAGS) fmcw.c -o fmcw $(LINKER_FLAGS)
