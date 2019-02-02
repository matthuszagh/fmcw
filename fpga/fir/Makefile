all:
	octave fir.m
	./dbl_to_hex.py
	cp taps.hex ../hdl
	cp taps.hex ../hdl/tb/
	./fmcw_defines.py
