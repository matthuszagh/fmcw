STRICT_FLAGS    = -Wall -Wextra -Wshadow -Wstrict-aliasing -ansi -pedantic -std=gnu11
FLAGS		= -O2 $(STRICT_FLAGS)
DEBUG_FLAGS	= -O0 -g $(STRICT_FLAGS)

exec: read_bytes
	./read_bytes

read_bytes: read_bytes.c Makefile
	gcc $(FLAGS) read_bytes.c -o read_bytes -lbitmanip

debug: read_bytes.c Makefile
	gcc $(DEBUG_FLAGS) read_bytes.c -o read_bytes -lbitmanip

.PHONY: exec debug
