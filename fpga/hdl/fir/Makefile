include ../Makefile.inc

resources:
	vivado -nolog -nojournal -mode batch -source run_vivado.tcl

tb: fir.v fir_poly.v decimate.v rom.v
	iverilog $(INCLUDE_DIRS) \
		-DSIMULATE fir.v -o tb/fir_tb
	./tb/fir_tb
	gtkwave tb/fir.vcd

.PHONY: resources tb


		# -DFILE_TAPS0_1=$(FILE_TAPS0_1) \
		# -DFILE_TAPS2_3=$(FILE_TAPS2_3) \
		# -DFILE_TAPS4_5=$(FILE_TAPS4_5) \
		# -DFILE_TAPS6_7=$(FILE_TAPS6_7) \
		# -DFILE_TAPS8_9=$(FILE_TAPS8_9) \
		# -DFILE_TAPS10_11=$(FILE_TAPS10_11) \
		# -DFILE_TAPS12_13=$(FILE_TAPS12_13) \
		# -DFILE_TAPS14_15=$(FILE_TAPS14_15) \
		# -DFILE_TAPS16_17=$(FILE_TAPS16_17) \
		# -DFILE_TAPS18_19=$(FILE_TAPS18_19) \
