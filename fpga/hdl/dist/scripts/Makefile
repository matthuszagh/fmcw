STRICT_FLAGS    = -Wall -Wextra -Wshadow -Wstrict-aliasing -ansi -pedantic -std=gnu11
FLAGS		= -O2 $(STRICT_FLAGS)
DEBUG_FLAGS	= -O0 -g $(STRICT_FLAGS)
LINK_FLAGS      = -lbitmanip -lm

exec: read_bytes
	./read_bytes

read_bytes: read_bytes.c Makefile
	gcc $(FLAGS) read_bytes.c -o read_bytes $(LINK_FLAGS)

debug: read_bytes.c Makefile
	gcc $(DEBUG_FLAGS) read_bytes.c -o read_bytes $(LINK_FLAGS)

missed_reads: missed_reads.c
	gcc $(FLAGS) missed_reads.c -o missed_reads

debug_missed_reads: missed_reads.c
	gcc $(DEBUG_FLAGS) missed_reads.c -o missed_reads

.PHONY: exec debug debug_missed_reads
