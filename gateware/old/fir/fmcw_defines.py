#!/usr/bin/env python3
"""Parameterize Verilog code."""

import numpy as np
import math
import bitstring

# from fir_common import *
from fir import FIR

if __name__ == "__main__":
    # ADC
    ADC_DATA_WIDTH = 12

    # FIR
    FIR_INPUT_WIDTH = ADC_DATA_WIDTH
    FIR_TAP_WIDTH = 16
    FIR_M = 20  # downsample factor
    FIR_M_WIDTH = int(np.ceil(np.log2(FIR_M)))

    _NUMTAPS = 1200
    _SAMPLING_FREQ = 40e6
    _NYQUIST_FREQ = _SAMPLING_FREQ / 2
    _BANDS = [0, 0.95e6, 1e6, _NYQUIST_FREQ]
    _BAND_GAIN = [1, 0]
    _FIR = FIR(_NUMTAPS, _BANDS, _BAND_GAIN, _SAMPLING_FREQ, pass_db=0.5)
    _FIR.write_poly_taps_files(["", "../hdl/fir/taps/"], FIR_TAP_WIDTH, FIR_M)
    FIR_INTERNAL_WIDTH = (
        FIR_INPUT_WIDTH + FIR_TAP_WIDTH + int(np.ceil(np.log2(_NUMTAPS)))
    )
    FIR_OUTPUT_WIDTH = _FIR.output_bit_width(FIR_INPUT_WIDTH)
    _FIR.write_input_sample_file(
        10000, FIR_M, FIR_INPUT_WIDTH, FIR_OUTPUT_WIDTH, ["../hdl/fir/tb/"]
    )
    # _FIR.dummy_in_out(FIR_INPUT_WIDTH)
    FIR_NORM_SHIFT = _FIR.tap_normalization_shift()
    FIR_POLY_BANK_LEN = int(_NUMTAPS / FIR_M)
    FIR_POLY_BANK_LEN_LOG2 = int(np.ceil(np.log2(FIR_POLY_BANK_LEN)))
    FIR_ROM_SIZE = int(2 ** (FIR_POLY_BANK_LEN_LOG2 + 1))

    # FFT
    FFT_TWIDDLE_WIDTH = 10
    # Distance calculation
    FFT_DIST_N = 1024
    FFT_DIST_N_LOG2 = int(np.log2(FFT_DIST_N))
    FFT_DIST_N_STAGES = int(math.log(FFT_DIST_N, 4))
    FFT_DIST_INPUT_WIDTH = FIR_OUTPUT_WIDTH
    FFT_DIST_INTERNAL_WIDTH = (
        FFT_DIST_INPUT_WIDTH
        # + FFT_TWIDDLE_WIDTH
        + 1
        + int(np.ceil(np.log2(FFT_DIST_N)))
    )
    # FFT_DIST_OUTPUT_WIDTH = FFT_DIST_INTERNAL_WIDTH - FFT_TWIDDLE_WIDTH
    FFT_DIST_OUTPUT_WIDTH = FFT_DIST_INTERNAL_WIDTH
    # Angle calculation
    FFT_ANGLE_N = 256
    FFT_ANGLE_N_LOG2 = int(np.log2(FFT_ANGLE_N))
    FFT_ANGLE_N_STAGES = int(math.log(FFT_ANGLE_N, 4))
    FFT_ANGLE_INPUT_WIDTH = FIR_OUTPUT_WIDTH
    FFT_ANGLE_INTERNAL_WIDTH = (
        FFT_ANGLE_INPUT_WIDTH
        # + FFT_TWIDDLE_WIDTH
        + 1
        + int(np.ceil(np.log2(FFT_ANGLE_N)))
    )
    # FFT_ANGLE_OUTPUT_WIDTH = FFT_ANGLE_INTERNAL_WIDTH - FFT_TWIDDLE_WIDTH
    FFT_ANGLE_OUTPUT_WIDTH = FFT_ANGLE_INTERNAL_WIDTH

    # USB
    USB_DATA_WIDTH = 8

    # SD
    SD_DATA_WIDTH = 4

    # GPIO
    GPIO_WIDTH = 6

    with open("../hdl/fmcw_defines.vh", "w") as f:
        f.write("`define FMCW_PARAMS parameter \\\n")
        # top
        f.write("GPIO_WIDTH = {}, \\\n".format(GPIO_WIDTH))
        f.write("USB_DATA_WIDTH = {}, \\\n".format(USB_DATA_WIDTH))
        f.write("ADC_DATA_WIDTH = {}, \\\n".format(ADC_DATA_WIDTH))
        f.write("SD_DATA_WIDTH = {}, \\\n".format(SD_DATA_WIDTH))
        # FIR
        f.write("FIR_M = {}, \\\n".format(FIR_M))
        f.write("FIR_M_WIDTH = {}, \\\n".format(FIR_M_WIDTH))
        f.write("FIR_INPUT_WIDTH = {}, \\\n".format(FIR_INPUT_WIDTH))
        f.write("FIR_INTERNAL_WIDTH = {}, \\\n".format(FIR_INTERNAL_WIDTH))
        f.write("FIR_NORM_SHIFT = {}, \\\n".format(FIR_NORM_SHIFT))
        f.write("FIR_OUTPUT_WIDTH = {}, \\\n".format(FIR_OUTPUT_WIDTH))
        f.write("FIR_TAP_WIDTH = {}, \\\n".format(FIR_TAP_WIDTH))
        f.write("FIR_POLY_BANK_LEN = {}, \\\n".format(FIR_POLY_BANK_LEN))
        f.write(
            "FIR_POLY_BANK_LEN_LOG2 = {}, \\\n".format(FIR_POLY_BANK_LEN_LOG2)
        )
        f.write("FIR_ROM_SIZE = {}, \\\n".format(FIR_ROM_SIZE))
        # general FFT
        f.write("FFT_TWIDDLE_WIDTH = {}, \\\n".format(FFT_TWIDDLE_WIDTH))
        # FFT distance calculation
        f.write("FFT_DIST_N = {}, \\\n".format(FFT_DIST_N))
        f.write("FFT_DIST_N_LOG2 = {}, \\\n".format(FFT_DIST_N_LOG2))
        f.write("FFT_DIST_N_STAGES = {}, \\\n".format(FFT_DIST_N_STAGES))
        f.write("FFT_DIST_INPUT_WIDTH = {}, \\\n".format(FFT_DIST_INPUT_WIDTH))
        f.write(
            "FFT_DIST_INTERNAL_WIDTH = {}, \\\n".format(
                FFT_DIST_INTERNAL_WIDTH
            )
        )
        f.write(
            "FFT_DIST_OUTPUT_WIDTH = {}, \\\n".format(FFT_DIST_OUTPUT_WIDTH)
        )
        # FFT angle calculation
        f.write("FFT_ANGLE_N = {}, \\\n".format(FFT_ANGLE_N))
        f.write("FFT_ANGLE_N_LOG2 = {}, \\\n".format(FFT_ANGLE_N_LOG2))
        f.write("FFT_ANGLE_N_STAGES = {}, \\\n".format(FFT_ANGLE_N_STAGES))
        f.write(
            "FFT_ANGLE_INPUT_WIDTH = {}, \\\n".format(FFT_ANGLE_INPUT_WIDTH)
        )
        f.write(
            "FFT_ANGLE_INTERNAL_WIDTH = {}, \\\n".format(
                FFT_ANGLE_INTERNAL_WIDTH
            )
        )
        f.write("FFT_ANGLE_OUTPUT_WIDTH = {}".format(FFT_ANGLE_OUTPUT_WIDTH))

    # FFT twiddle factors
    STAGES = int(math.log(FFT_DIST_N, 4) - 1)
    for s in range(0, FFT_DIST_N_STAGES):
        with open("../hdl/fft/fft_r22sdf_rom_s{}_re.hex".format(s), "w") as f:
            for k in [0, 2, 1, 3]:
                for n in range(0, int(FFT_DIST_N / (2 ** (2 * s + 2)))):
                    exp = 4 ** s * n * k
                    real = np.real(np.exp(-2 * np.pi * 1j * exp / FFT_DIST_N))
                    if real >= 0:
                        real_int = int(
                            (2 ** (FFT_TWIDDLE_WIDTH - 1) - 1) * real
                        )
                    else:
                        real_int = int(
                            2 ** (FFT_TWIDDLE_WIDTH)
                            + (2 ** (FFT_TWIDDLE_WIDTH - 1) * real)
                        )
                    f.write("{:X}\n".format(real_int))

        with open("../hdl/fft/fft_r22sdf_rom_s{}_im.hex".format(s), "w") as f:
            for k in [0, 2, 1, 3]:
                for n in range(0, int(FFT_DIST_N / (2 ** (2 * s + 2)))):
                    exp = 4 ** s * n * k
                    imag = np.imag(np.exp(-2 * np.pi * 1j * exp / FFT_DIST_N))
                    if imag >= 0:
                        imag_int = int(
                            (2 ** (FFT_TWIDDLE_WIDTH - 1) - 1) * imag
                        )
                    else:
                        imag_int = int(
                            2 ** (FFT_TWIDDLE_WIDTH)
                            + (2 ** (FFT_TWIDDLE_WIDTH - 1) * imag)
                        )
                    f.write("{:X}\n".format(imag_int))

    # # compute max output value
    # max_val = 0
    # min_val = 0
    # for k in range(FFT_DIST_N):
    #     cur_max = 0
    #     cur_min = 0
    #     for n in range(FFT_DIST_N):
    #         twiddle = np.exp(-2 * np.pi * 1j * n * k / FFT_DIST_N)
    #         input_max = 2 ** (FFT_DIST_INPUT_WIDTH - 1) - 1
    #         input_min = -2 ** (FFT_DIST_INPUT_WIDTH - 1)
    #         if np.real(twiddle) > 0:
    #             cur_max += np.real(twiddle) * input_max
    #             cur_min += np.real(twiddle) * input_min
    #         else:
    #             cur_max += np.real(twiddle) * input_min
    #             cur_min += np.real(twiddle) * input_max

    #         if np.imag(twiddle) > 0:
    #             cur_max -= np.imag(twiddle) * input_min
    #             cur_min -= np.imag(twiddle) * input_max
    #         else:
    #             cur_max -= np.imag(twiddle) * input_max
    #             cur_min -= np.imag(twiddle) * input_min

    #     if cur_max > max_val:
    #         max_val = cur_max
    #     if cur_min < min_val:
    #         min_val = cur_min

    # print(max_val)
    # print(min_val)

    # Input data for FFT testbench
    input_signal = np.zeros(FFT_DIST_N)
    freqs = np.linspace(100e3, 1e6, 100)
    for i in range(FFT_DIST_N):
        for f in freqs:
            input_signal[i] += np.sin(2 * np.pi * f * i)

    input_signal *= (2 ** (FFT_DIST_INPUT_WIDTH - 1) - 1) / np.max(
        np.absolute(input_signal)
    )
    with open("fft_sample_in_1024.txt", "w") as f:
        for sig in input_signal:
            f.write("{}\n".format(int(sig)))

    with open("fft_sample_in_1024.txt", "r") as fin:
        with open("../hdl/fft/tb/fft_samples_1024.hex", "w") as fout:
            for line in fin:
                val = float(line.split()[0])
                # if FFT_DIST_INPUT_WIDTH % 4 != 0:
                #     nbits = int(4 * math.ceil(FFT_DIST_INPUT_WIDTH / 4))
                # hex_val = bitstring.BitArray(int=int(val), length=nbits).hex
                # fout.write(hex_val)
                # fout.write("\n")
                if val >= 0:
                    val_int = int(val)
                else:
                    val_int = int(2 ** (FFT_DIST_INPUT_WIDTH) + val)
                fout.write("{:X}\n".format(val_int))

    # Output data for FFT testbench
    with open("fft_sample_in_1024.txt", "r") as f:
        data = f.readlines()
        data = [x.replace(" ", "") for x in data]
        data = [x.replace("\n", "") for x in data]
        data = [float(x) for x in data]

    fft_res = np.fft.fft(data)

    with open("../hdl/fft/tb/fft_res1024.txt", "w") as f:
        for i in range(len(fft_res)):
            real = np.real(fft_res[i])
            imag = np.imag(fft_res[i])
            f.write("{:8d}".format(int(real)))
            f.write(" ")
            f.write("{:8d}".format(int(imag)))
            f.write("\n")
