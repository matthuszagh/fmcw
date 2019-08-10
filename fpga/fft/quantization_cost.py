#!/usr/bin/env python3

import numpy as np
from matplotlib import pyplot as plt

N = 1024

sample_data = np.zeros(1024, dtype=int)

with open("sample.txt", "r") as f:
    cnt = 0
    for line in f:
        val = line.split()
        val = float(val[0])
        val = int(val)
        sample_data[cnt] = val
        cnt += 1

# hist, bins = np.histogram(sample_data, int(max(sample_data)/100))
# plt.plot(hist)
# plt.show()

# only use reals
fft = np.fft.fft(sample_data)
fft_int = np.zeros(len(fft), dtype=int)
for i in range(0, len(fft)):
    fft_int[i] = int(np.real(fft[i]))

hist, bins = np.histogram(fft_int, int(max(fft_int)/(100*2**8)))
plt.plot(hist, scalex=100)
plt.show()

fft_16 = np.zeros(len(fft), dtype=int)
for i in range(0, len(fft)):
    tmp = fft_int[i] >> 8
    if (tmp < 0):
        fft_16[i] = tmp % (-2**15)
    else:
        fft_16[i] = tmp % (2**15-1)

# hist, bins = np.histogram(fft_16, int(max(fft_16)/100))
# plt.plot(hist, scalex=100)
# plt.show()
