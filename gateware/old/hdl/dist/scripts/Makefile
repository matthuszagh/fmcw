DEBUG           = 0

COMPILER        = clang
STRICT_FLAGS    = -Wall -Wextra -Wshadow -Wstrict-aliasing -ansi -pedantic -std=gnu11
PERF_FLAGS	= -O2 $(STRICT_FLAGS)
DEBUG_FLAGS	= -O0 -g3 $(STRICT_FLAGS)
LINK_FLAGS      = -lbitmanip -lm
ifeq ($(DEBUG),1)
FLAGS           = $(DEBUG_FLAGS)
else
FLAGS           = $(PERF_FLAGS)
endif


.PHONY: exec
exec: gen_plot_data
	./gen_plot_data

gen_plot_data: gen_plot_data.c Makefile
	$(COMPILER) $(FLAGS) gen_plot_data.c -o gen_plot_data $(LINK_FLAGS)

valgrind:
	valgrind --leak-check=full \
         --show-leak-kinds=all \
         --track-origins=yes \
         --verbose \
         --log-file=valgrind-out.txt \
         ./gen_plot_data

.PHONY: clean
clean:
	rm -f gen_plot_data
