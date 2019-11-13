CC		= clang
DEBUG		= 0
PLOT		= 0

ifeq ($(DEBUG),0)
CFLAGS	= -O3
else
CFLAGS	= -O0 -g3
endif
STRICT_CFLAGS	= $(CFLAGS) -Wall -Wextra -Wshadow -Wstrict-aliasing -ansi -pedantic -Werror
FTDI_CFLAGS	:= $(shell libftdi1-config --cflags)
LINKER_FLAGS	:= $(shell libftdi1-config --libs)

.PHONY: acquire
acquire: read
	rm -rf data
	mkdir data
	./plot.py &
	sudo ./read

read: read.c bitmanip.c bitmanip.h
	$(CC) $(CFLAGS) $(FTDI_CFLAGS) read.c bitmanip.c -o read -lm $(LINKER_FLAGS)
