all: | collect analyze movie

collect:
	./fmcw.py

analyze:
	rm -rf img
	mkdir -p img
	./plot_log.py fmcw.log
	chmod a+rw img/*

movie:
	rm -f mov.mp4
	./gen_mov.sh
	chmod a+rw mov.mp4

.PHONY: all collect analyze movie
