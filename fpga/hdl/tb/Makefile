all:
	iverilog fir_tb.v -I ../ -o fir_tb
	iverilog downsample_tb.v -I ../ -o downsample_tb
	iverilog adf4158_tb.v -I ../ -o adf4158_tb
	iverilog kaiser_tb.v -I ../ -o kaiser_tb
	iverilog chan_split_tb.v -I ../ -o chan_split_tb

fir: fir_tb.v ../taps.hex
	iverilog fir_tb.v -I ../ -o fir_tb
	./fir_tb
	gtkwave fir.vcd

fft: fft_r22sdf_tb.v
	iverilog fft_r22sdf_tb.v -I ../ -o fft_r22sdf_tb
	./fft_r22sdf_tb
	gtkwave fft_r22sdf_tb.vcd

downsample: all downsample_tb.v
	./downsample_tb
	gtkwave downsample.vcd

adf4158: all adf4158_tb.v
	./adf4158_tb
	gtkwave adf4158.vcd

kaiser: all kaiser_tb.v
	./kaiser_tb
	gtkwave kaiser.vcd

chan_split: all chan_split_tb.v
	./chan_split_tb
	gtkwave chan_split.vcd

.PHONY: all fft kaiser chan_split fir downsample adf4158
