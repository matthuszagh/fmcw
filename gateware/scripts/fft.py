#!/usr/bin/env python

import bit
import numpy as np


class FFT:
    """FFT utility."""

    def __init__(self, length, radix):
        if radix != 4:
            raise ValueError(
                """Support is currently limited to radix 4."""
                """ Other radices should be implemented."""
            )
        self.radix = radix
        num_stages = np.log(length) / np.log(radix)
        if abs(num_stages - int(num_stages)) > 0.0001:
            raise ValueError("""length must be a power of the chosen radix.""")
        self.num_stages = int(num_stages)
        self.length = length
        # number of twiddle factors in each stage
        self._twiddle_lens = [
            int(self.length * ((1 / 4) ** (s + 1)))
            for s in range(self.num_stages)
        ]
        self.twiddles = self.compute_twiddles()

    def compute_twiddles(self):
        """
        Compute the twiddle factors for each stage.

        @returns A 2-dimensional numpy array where the outer dimension
        corresponds to the stage and the inner dimension corresponds
        to the twiddle factor index.
        """
        twiddles = np.zeros((self.num_stages, self.length), dtype=complex)
        # bit-reversed index for each radix-length FFT
        # TODO generalize for non radix-4 FFTs
        ks = [0, 2, 1, 3]
        for s, twiddle_len in enumerate(self._twiddle_lens):
            for knorm, k in enumerate(ks):
                for n in range(twiddle_len):
                    exp = (self.radix ** s) * n * k
                    twiddle = np.exp(-2 * np.pi * 1j * exp / self.length)
                    twiddles[s][knorm * twiddle_len + n] = twiddle

        return twiddles

    def write_twiddle_roms(self, dirpaths, prec):
        """
        Write twiddle rom files to a list of directories.

        Each stage gets its own file and the real and imaginary parts
        also get their own file.

        @dirpaths the list of directory paths.
        @prec the number of bits for each twiddle factor.
        """
        for d in dirpaths:
            for s, stage_twiddles in enumerate(self.twiddles):
                reals = np.real(stage_twiddles)
                imags = np.imag(stage_twiddles)
                real_fname = "s" + str(s) + "_re.hex"
                imag_fname = "s" + str(s) + "_im.hex"
                if d[-1] != "/":
                    d = d + "/"

                with open(d + real_fname, "w") as f:
                    for i, real in enumerate(reals):
                        if i >= self.radix * self._twiddle_lens[s]:
                            continue
                        twint = bit.sub_integral_to_sint(real, prec)
                        twhex = bit.int_to_hex(twint, prec)
                        f.write(twhex + "\n")

                with open(d + imag_fname, "w") as f:
                    for i, imag in enumerate(imags):
                        if i >= self.radix * self._twiddle_lens[s]:
                            continue
                        twint = bit.sub_integral_to_sint(imag, prec)
                        twhex = bit.int_to_hex(twint, prec)
                        f.write(twhex + "\n")


FFT = FFT(1024, 4)
FFT.write_twiddle_roms(["../roms/fft/"], 10)
