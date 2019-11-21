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
LINKER_FLAGS	:= $(shell libftdi1-config --libs)

.PHONY: acquire
acquire: fmcw
	rm -rf data
	mkdir data
ifeq ($(DEBUG),0)
	./plot.py &
	./fmcw
endif

fmcw: fmcw.c bitmanip.c bitmanip.h
	$(CC) $(CFLAGS) $(FTDI_CFLAGS) fmcw.c bitmanip.c -o fmcw -lm $(LINKER_FLAGS)
