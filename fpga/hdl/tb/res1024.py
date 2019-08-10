#!/usr/bin/env python3

import numpy as np

right_shift = 8

with open("data1024.txt", "r") as f:
    data = f.readlines()
    data = [x.replace(" ", "") for x in data]
    data = [x.replace("\n", "") for x in data]
    data = [float(x) for x in data]

fft_res = np.fft.fft(data)

with open("res1024.txt", "w") as f:
    for i in range(len(fft_res)):
        real = np.real(fft_res[i])
        imag = np.imag(fft_res[i])
        f.write("{:8d}".format(int(real/2**right_shift)))
        f.write(" ")
        f.write("{:8d}".format(int(imag/2**right_shift)))
        f.write("\n")
