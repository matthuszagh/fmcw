CC		= clang

CFLAGS		= -O3 -march=native
STRICT_CFLAGS	= $(CFLAGS) -Wall -Wextra -Wshadow -Wstrict-aliasing -ansi -pedantic -Werror
FTDI_CFLAGS	:= $(shell libftdi1-config --cflags)
LINKER_FLAGS	:= $(shell libftdi1-config --libs) -lm -lpthread

read: read.c
	bear $(CC) $(CFLAGS) $(FTDI_CFLAGS) read.c -o read $(LINKER_FLAGS)
