#!/usr/bin/env python

import libdigital.tools.fft as fft

FFT = fft.FFT(1024, 4)
FFT.write_twiddle_roms(["../roms/fft/"], 10)
