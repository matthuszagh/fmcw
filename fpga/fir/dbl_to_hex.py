#!/usr/bin/env python3

from fir_common import *

quantization_bits = 16

fparams = open("hdl_params.yml", "a")
fparams.write("TW: {0}\n".format(quantization_bits))

fin = open("fir_coeffs.dbl", "r")
fint = open("fir_coeffs.int", "w")
fout = open("taps.hex", "w")

dbl_arr = fin.read().split('\n')
dbl_arr = list(filter(None, dbl_arr))
dbl_arr = [float(i) for i in dbl_arr]

for dbl in dbl_arr:
    val = quantize(dbl, quantization_bits)
    fint.write(str(val))
    fint.write('\n')
    fout.write(format(val % (1 << quantization_bits), 'x'))
    fout.write('\n')
