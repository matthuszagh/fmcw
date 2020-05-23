.PHONY: prog
prog: build/top.bit openocd/*
	openocd -f openocd/interface.cfg -f openocd/program_fpga.cfg

build/top.bit: top.py ltc2292.py
	./top.py build
