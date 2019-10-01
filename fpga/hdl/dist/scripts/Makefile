FLAGS = -O0 -g -Wall -Wextra -Wshadow -Wstrict-aliasing -ansi -pedantic -std=gnu11

exec: read_bytes
	./read_bytes

read_bytes: read_bytes.c Makefile
	gcc $(FLAGS) read_bytes.c -o read_bytes -lbitmanip

.PHONY: exec
