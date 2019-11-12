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

generate_plot: gen_plot
	sudo ./gen_plot
ifeq ($(PLOT),1)
	python -i plot.py
endif

gen_plot: main.c bitmanip.c bitmanip.h
	$(CC) $(CFLAGS) $(FTDI_CFLAGS) main.c bitmanip.c -o gen_plot -lm $(LINKER_FLAGS)

# bitmanip.o: bitmanip.c bitmanip.h
# 	$(CC) $(STRICT_CFLAGS) -c bitmanip.c

.PHONY: acquire
acquire: read
	rm -rf data/*
	sudo ./read

read: read.c bitmanip.c bitmanip.h
	$(CC) $(CFLAGS) $(FTDI_CFLAGS) read.c bitmanip.c -o read -lm $(LINKER_FLAGS)

# read: read.c
# 	sudo rmmod ftdi_sio
# 	$(CC) $(CFLAGS) $(FTDI_CFLAGS) read.c -o read $(LINKER_FLAGS)
