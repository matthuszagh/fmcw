#!/usr/bin/env python3

import numpy as np
from fir_common import *

quantization_bits = 16
kaiser_beta = 6
chan_len = 1000

w = np.kaiser(chan_len, kaiser_beta)
w *= len(w)/np.sum(w)
bit_int = []

fout = open("kaiser.hex", "w")

for dbl in w:
    bit_int = int(quantize(dbl, quantization_bits))
    fout.write(format(bit_int % (1 << quantization_bits), 'x'))
    fout.write('\n')
