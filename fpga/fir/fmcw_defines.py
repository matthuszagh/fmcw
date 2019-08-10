#!/usr/bin/env python3

import yaml
import math
import numpy as np
from fir_common import *

fparams = open("hdl_params.yml", "r")
dat = yaml.safe_load(fparams)

FFT_N = 1024
FFT_STAGES = int(math.log(FFT_N, 4))
FFT_NLOG2 = int(math.log2(FFT_N))
TWIDDLE_WIDTH = 10
USBDW = 8  # USB data width.
SDDW = 4  # SD card data width.
GPIOW = 6  # GPIO pins.
M = 20  # Downsample.
MW = math.ceil(math.log2(M))  # Downsample bits.
IW = 12  # Input bit width.
OW = compute_bits(IW, "fir_coeffs.dbl")  # Output bit width.
NTAPS = dat['NTAPS']
# Counter bit width for iterating through taps.
CntW = math.ceil(math.log2(NTAPS))
if OW > 16:
    print("Error: Outputs may overflow 16 bits.")
    exit(2)
else:
    OW = 16

OW = 24
FFTDW = OW + 8  # use 8 guard bits for FFt
# # TODO tmp!!!!
# FFTDW = OW + 20  # use 8 guard bits for FFt

f = open("../hdl/fmcw_defines.vh", "w")
f.write('`define FMCW_DEFAULT_PARAMS parameter \\\n')
f.write('NTAPS = {0}, \\\n'.format(NTAPS))
f.write('CntW = {0}, \\\n'.format(CntW))
f.write('TW = {0}, \\\n'.format(dat['TW']))
f.write('IW = {0}, \\\n'.format(IW))
f.write('OW = {0}, \\\n'.format(OW))
f.write('IntW = {0}, \\\n'.format(compute_bits(IW, "fir_coeffs.int")))
f.write('USBDW = {0}, \\\n'.format(USBDW))
f.write('SDDW = {0}, \\\n'.format(SDDW))
f.write('GPIOW = {0}, \\\n'.format(GPIOW))
f.write('FFT_N = {0}, \\\n'.format(FFT_N))
f.write('FFT_STAGES = {0}, \\\n'.format(FFT_STAGES))
f.write('FFT_NLOG2 = {0}, \\\n'.format(FFT_NLOG2))
f.write('FFTDW = {0}, \\\n'.format(FFTDW))
f.write('TWIDDLE_WIDTH = {0}, \\\n'.format(TWIDDLE_WIDTH))
f.write('Cnt_STAGE = {0}, \\\n'.format(math.ceil(math.log2(FFT_STAGES))))
f.write('M = {0}, \\\n'.format(M))
f.write('MW = {0}\n'.format(MW))
f.close()

# fft twiddle factors
stages = int(math.log(FFT_N, 4)-1)
for s in range(0, stages):
    with open("../hdl/fft_r22sdf_rom_s{}.hex".format(s), "w") as f:
        # sections = int(2**(2*s+2)/4)
        # for j in range(0, sections):
        for k in [0, 2, 1, 3]:
            for n in range(0, int(FFT_N/(2**(2*s+2)))):
                exp = 4**s*n*k
                real = np.real(np.exp(-2*np.pi*1j*exp/FFT_N))
                imag = np.imag(np.exp(-2*np.pi*1j*exp/FFT_N))
                if (real >= 0):
                    real_int = int((2**(TWIDDLE_WIDTH-1)-1)*real)
                else:
                    real_int = int(2**(TWIDDLE_WIDTH) +
                                   (2**(TWIDDLE_WIDTH-1)*real))
                if (imag >= 0):
                    imag_int = int((2**(TWIDDLE_WIDTH-1)-1)*imag)
                else:
                    imag_int = int(2**(TWIDDLE_WIDTH) +
                                   (2**(TWIDDLE_WIDTH-1)*imag))
                # f.write("{:3X} {:3X}\n".format(real_int, imag_int))
                f.write("{:X} {:X}\n".format(real_int, imag_int))


# # fft twiddle factors
# index = np.linspace(0, int(FFT_N/2-1), int(FFT_N/2), dtype=int)
# twiddle = np.exp(-2*np.pi*1j*index/FFT_N)
# # twiddle_out = np.zeros((int(FFT_N/2), 2), dtype=int)
# f = open("../hdl/twiddle_b.data", "w")
# for i in range(0, len(twiddle)-1):
#     twiddle_out_real_int = int(2**(OW-1)*(np.real(twiddle[i])))
#     if (twiddle_out_real_int == 2**(OW-1)):
#         twiddle_out_real_int = twiddle_out_real_int - 1
#     twiddle_out_real = np.binary_repr(twiddle_out_real_int, OW)

#     twiddle_out_imag_int = int(2**(OW-1)*(np.imag(twiddle[i])))
#     if (twiddle_out_imag_int == 2**(OW-1)):
#         twiddle_out_imag_int = twiddle_out_imag_int - 1
#     twiddle_out_imag = np.binary_repr(twiddle_out_imag_int, OW)

#     f.write(str(twiddle_out_real))
#     f.write(" ")
#     f.write(str(twiddle_out_imag))
#     f.write("\n")

# f.close()

# # compute indices for each butterfly computation
# f = open("../hdl/butterfly_indices.data", "w")
# for s in range(0, FFT_STAGES):
#     indices = np.linspace(0, FFT_N-1, int(FFT_N))
#     for i in range(0, FFT_N-1):
#         if (i in indices):
#             first = i
#             offset = int(FFT_N/(2**(s+1)))
#             second = i + offset
#             f.write(str(int(first)))
#             f.write(" ")
#             f.write(str(int(second)))
#             f.write("\n")
#             index = np.argwhere(indices == first)
#             indices = np.delete(indices, index)
#             index2 = np.argwhere(indices == second)
#             indices = np.delete(indices, index2)
# f.close()
