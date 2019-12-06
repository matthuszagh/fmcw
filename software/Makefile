CC		= clang
DEBUG		?= 0
PLOT		= 0

ifeq ($(DEBUG),1)
CFLAGS	= -O0 -g3
else
CFLAGS	= -O3
endif
STRICT_CFLAGS	= $(CFLAGS) -Wall -Wextra -Wshadow -Wstrict-aliasing -ansi -pedantic -Werror
FTDI_CFLAGS	:= $(shell libftdi1-config --cflags)
LINKER_FLAGS	:= $(shell libftdi1-config --libs) -lm -lpthread

.PHONY: acquire
acquire: fmcw
	rm -rf data
	mkdir data
ifeq ($(DEBUG),0)
	./plot.py &
	./fmcw -a dist
endif

fmcw: fmcw.c bitmanip.c bitmanip.h
	$(CC) $(CFLAGS) $(FTDI_CFLAGS) fmcw.c bitmanip.c -o fmcw $(LINKER_FLAGS)

.PHONY: valgrind
valgrind:
	rm -f fmcw
	$(CC) -O0 -g3 $(FTDI_CFLAGS) fmcw.c bitmanip.c -o fmcw $(LINKER_FLAGS)
	valgrind --leak-check=yes ./fmcw
