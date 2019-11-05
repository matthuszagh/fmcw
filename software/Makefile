COMPILER	= clang
CFLAGS		= -O3 -Wall -Wextra -Wshadow -Wstrict-aliasing -ansi -pedantic -Werror

.PHONY: all
all: read

read: main.c
	$(COMPILER) $(CFLAGS) -o read main.c
