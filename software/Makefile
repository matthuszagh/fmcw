COMPILER	= clang
DEBUG		= 0
ifeq ($(DEBUG),0)
CFLAGS	= -O3
else
CFLAGS	= -O0 -g3
endif
STRICT_CFLAGS	= $(CFLAGS) -Wall -Wextra -Wshadow -Wstrict-aliasing -ansi -pedantic -Werror
FTDI_CFLAGS	:= $(shell libftdi1-config --cflags)
LINKER_FLAGS	:= $(shell libftdi1-config --libs)

generate_plot: gen_plot
	./gen_plot

gen_plot: main.c read bitmanip.c bitmanip.h
	$(COMPILER) $(CFLAGS) main.c bitmanip.c -o gen_plot

# bitmanip.o: bitmanip.c bitmanip.h
# 	$(COMPILER) $(STRICT_CFLAGS) -c bitmanip.c

.PHONY: acquire
acquire: read
	sudo ./read read.bin

read: read.c
	sudo rmmod ftdi_sio
	$(COMPILER) $(CFLAGS) $(FTDI_CFLAGS) read.c -o read $(LINKER_FLAGS)
