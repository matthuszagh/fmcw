#!/usr/bin/env python

import math
from scipy import signal
import bitstring
import matplotlib.pyplot as plt
import numpy as np
import bit


class FIR:
    """
    Finite-impulse response filter.
    """

    def __init__(self, numtaps, bands, band_gain, fs, pass_db=1, stop_db=-40):
        w = [1 / (1 - 10 ** (-pass_db / 20)), 1 / (10 ** (stop_db / 20))]
        self.fs = fs
        self.taps = signal.remez(
            numtaps=numtaps,
            bands=bands,
            desired=band_gain,
            weight=w,
            fs=fs,
            type="bandpass",
        )

    # TODO deprecate in favor of bit functions
    def quantize_2s_comp(self, nbits, val, max_val=1):
        """
        Quantize a real number (val) for two's complement representation
        using a supplied number of bits (nbits). The original range of
        values is [-max_val, max_val].
        """
        norm_val = val / max_val
        return round(norm_val * 2 ** (nbits - 1))

    def quantized_taps(self, nbits, taps=None):
        """
        Quantize all taps for two's complement representation with `nbits'
        bits. This assumes a tap value range of [-1,1]. If you do not
        provide taps, this uses self.taps.
        """
        if taps is None:
            taps = self.taps

        new_taps = np.zeros(len(taps))
        for i, tap in enumerate(taps):
            new_taps[i] = bit.quantized_real(tap, nbits)
        return new_taps

    # TODO deprecate in favor of bit functions
    def as_hex(self, nbits, taps=None):
        """
        FIR tap array in hexadecimal representation using `nbits'
        bits.

        When using this for synthesis, you should only provide a
        number of bits that is a multiple of 4. Other values can lead
        to unexpected errors.
        """
        if taps is None:
            taps = self.taps

        # TODO this is necessary due to the limitations of
        # bitstring. This should be rewritten to support non-multiples
        # of 4.
        if nbits % 4 != 0:
            nbits = int(4 * math.ceil(nbits / 4))

        hex_taps = []
        for elt in taps:
            bit_val = self.quantize_2s_comp(nbits, elt)
            hex_taps.append(
                bitstring.BitArray(int=int(bit_val), length=nbits).hex
            )
        return hex_taps

    # TODO deprecate in favor of bit functions
    def as_dec(self, nbits, taps=None):
        """
        Similar to as hex, but generates decimal output.
        """
        if taps is None:
            taps = self.taps

        new_taps = []
        for tap in taps:
            val = self.quantize_2s_comp(nbits, tap)
            new_taps.append(val)
            # if elt < 0:
            #     val = int(elt * 2 ** (nbits - 1))
            #     new_seq.append(val)
            # else:
            #     val = int(elt * 2 ** (nbits - 1) - 1)
            #     new_seq.append(val)

        return new_taps

    def output_bit_width(self, nbits):
        """
        Compute the number of output bits needed to represent every
        result. `nbits' is the number of bits in each input
        sample. This function takes the most pessimistic possible view
        of the input samples. Specifically, that all negative taps are
        multiplied by the most negative possible input and all
        positive taps are multiplied by the most positive possible
        input.
        """
        min_input = -(2 ** (nbits - 1))
        max_input = 2 ** (nbits - 1) - 1
        output = 0
        for tap in self.taps:
            if tap < 0:
                output += tap * min_input
            else:
                output += tap * max_input

        output_bits = int(np.ceil(np.log2(output + 1) + 1))
        return output_bits

    def tap_normalization_shift(self, taps=None):
        """
        Compute a normalization factor that can be used to make more
        efficient use of bits for the taps. Tap abs(values) are often
        much less than 1, so if we assume they range from -1 to 1 we
        waste a lot of bits representing values that can never
        exist. This function finds a factor power of 2 (for easy bit
        shifts) that scales each tap to fill more of the range
        [-1,1]. To get the right result at the end, simply right shift
        by this amount.
        """
        if taps is None:
            taps = self.taps

        max_tap = np.max(np.abs(taps))
        factor = 1 / max_tap
        return int(np.floor(np.log2(factor)))

    def normalized_taps(self, taps=None):
        """
        Scale all taps by the shift returned by `tap_normalization_shift'.
        """
        if taps is None:
            taps = self.taps

        factor = 2 ** self.tap_normalization_shift(taps=taps)
        new_taps = np.zeros(len(taps))
        for i, _ in enumerate(taps):
            new_taps[i] = factor * taps[i]
        return new_taps

    # TODO deprecate
    def write_taps_file(self, paths, nbits):
        """Write taps in hex format to each file specified in path."""
        fir_hex = self.as_hex(nbits, use_taps=True)
        for path in paths:
            with open(path, "w") as f:
                for val in fir_hex:
                    f.write("{}\n".format(val))

    def write_poly_taps_files(
        self,
        dirs,
        nbits,
        downsample_factor,
        normalize_taps=True,
        combine_adjacent_taps_files=False,
    ):
        """
        Write taps separated into polyphase components. Each polyphase
        filter is written to its own file. This method uses normalized
        taps by default for more efficient bit representation. Note
        that if you use normalized taps you must scale the result by
        the normalization factor. See `normalization_shift' for the
        factor. `combine_adjacent_taps_files' places the taps for two
        filter banks in the same file. This is useful when storing the
        taps in block ram, since it allows you to use the RAM as
        dual-port RAM and cut the number of block RAMs in half.
        """
        if normalize_taps:
            taps = self.normalized_taps()

        fir_hex = []
        for i, tap in enumerate(taps):
            quant_tap = bit.sub_integral_to_sint(tap, nbits)
            fir_hex.append(bit.int_to_hex(quant_tap, nbits))

        if combine_adjacent_taps_files == False:
            for d in dirs:
                if d[-1] != "/":
                    d = d + "/"
                for filt in range(downsample_factor):
                    path = d + "taps" + str(filt) + ".hex"
                    with open(path, "w") as f:
                        for i, val in enumerate(fir_hex):
                            if i % downsample_factor == filt:
                                f.write("{}\n".format(val))

        else:
            for d in dirs:
                if d[-1] != "/":
                    d = d + "/"
                for filt in range(0, downsample_factor, 2):
                    path = (
                        d + "taps" + str(filt) + "_" + str(filt + 1) + ".hex"
                    )
                    with open(path, "w") as f:
                        for i, val in enumerate(fir_hex):
                            if i % downsample_factor == filt:
                                f.write("{}\n".format(val))
                        # TODO this is not properly parameterized
                        for _ in range(4):
                            f.write("0000\n")
                        for i, val in enumerate(fir_hex):
                            if i % downsample_factor == filt + 1:
                                f.write("{}\n".format(val))
                        for _ in range(4):
                            f.write("0000\n")

    def pass_ripple(self, taps, band, fs):
        """
        Compute peak passband ripple for an FIR filter specified by its
        taps. band is the bandpass region, which must a list of 2
        elements for the start and end of the region, respectively. fs
        is the sampling frequency.
        """
        num_freqs = 1024
        freqs, resp = signal.freqz(taps, [1], worN=num_freqs, fs=fs)
        fn = fs / 2
        delta_f = fn / num_freqs
        band_low = band[0]
        band_high = band[1]

        max_ripple = 0
        for i in range(len(freqs)):
            freq = freqs[i]
            if band_low <= freq <= band_high:
                gain_db = 20 * np.log10(np.abs(resp[i]))
                ripple = np.abs(gain_db)
                if ripple > max_ripple:
                    max_ripple = ripple

        return max_ripple

    def plot_response(self, savefile, taps=None):
        """Utility function to plot response functions."""
        if taps is None:
            taps = self.taps

        fig = plt.figure()
        ax = fig.add_subplot(111)
        w, h = signal.freqz(taps, [1], worN=1024)
        ax.plot(0.5 * self.fs * w / np.pi, 20 * np.log10(np.abs(h)))
        ax.set_ylim(-80, 5)
        ax.set_xlim(0, 0.1 * self.fs)
        ax.grid(True)
        ax.set_xlabel("Frequency (Hz)")
        ax.set_ylabel("Gain (dB)")
        ax.set_title("FIR Response")
        fig.show()
        fig.savefig(savefile)


fir = FIR(
    numtaps=120,
    bands=[0, 1e6, 1.5e6, 20e6],
    band_gain=[1, 0],
    fs=40e6,
    pass_db=0.5,
    stop_db=-40,
)

tap_bits = 16
input_bits = 12
downsample_factor = 20
fir.write_poly_taps_files(
    ["../roms/fir/"], tap_bits, downsample_factor, True, False
)
# fir.plot_response("freq_response.png")
print("normalization shift: {}".format(fir.tap_normalization_shift()))
print("output bits: {}".format(fir.output_bit_width(input_bits)))
