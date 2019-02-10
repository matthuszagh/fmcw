all:
	iverilog fir_tb.v -I ../ -o fir_tb
	iverilog downsample_tb.v -I ../ -o downsample_tb
	iverilog adf4158_tb.v -I ../ -o adf4158_tb

fir: fir_tb.v
	./fir_tb
	gtkwave fir.vcd

downsample: downsample_tb.v
	./downsample_tb
	gtkwave downsample.vcd

adf4158: adf4158_tb.v
	./adf4158_tb
	gtkwave adf4158.vcd

.PHONY: all fir downsample adf4158
