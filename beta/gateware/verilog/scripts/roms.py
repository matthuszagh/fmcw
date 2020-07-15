import os
import numpy as np
from bit import sub_integral_to_uint
from fir import FIR, fir_response
from fft import FFT


def set_env(varname: str, value: str):
    """
    """
    with open("env.sh", "a") as f:
        f.write("export {}={}\n".format(varname, value))
    print(
        "Setting environment variable '{}' to value '{}'.".format(
            varname, value
        )
    )


try:
    os.remove("env.sh")
except OSError:
    pass

# FIR roms
fir = FIR(
    numtaps=120,
    bands=[0, 0.5e6, 1e6, 20e6],
    band_gain=[1, 0],
    fs=40e6,
    pass_db=0.5,
    stop_db=-40,
)

tap_bits = 16
input_bits = 12
downsample_factor = 20
fir.write_poly_taps_files(
    ["src/roms/fir/"], tap_bits, downsample_factor, True, False
)
fir.print_response("freq_response.dat")
set_env("FIR_TAP_WIDTH", tap_bits)
set_env("FIR_NORM_SHIFT", fir.tap_normalization_shift())
fir_output_bits = fir.output_bit_width(input_bits)
set_env("FIR_OUTPUT_WIDTH", fir_output_bits)

# with open("coeff40_2.dat") as f:
#     taps = [float(line.rstrip("\n")) for line in f]
#     fir.taps = taps
#     fir.write_poly_taps_files(
#         ["../roms/fir/"], tap_bits, downsample_factor, True, False
#     )
#     fir_response("40_2_response.dat", taps=taps, fs=40e6)
#     set_env("FIR_TAP_WIDTH", tap_bits)
#     set_env("FIR_NORM_SHIFT", fir.tap_normalization_shift())
#     set_env("FIR_OUTPUT_WIDTH", fir.output_bit_width(input_bits))

# FFT roms
fft = FFT(1024, 4)
# fft_twiddle_bits = 10
fft_twiddle_bits = 18
fft.write_twiddle_roms(["src/roms/fft/"], fft_twiddle_bits)
set_env("FFT_TWIDDLE_WIDTH", fft_twiddle_bits)
set_env("FFT_OUTPUT_WIDTH", fft.output_bit_width(fir_output_bits))

# window roms
N = 1024
COEFF_PREC = 16

w = np.kaiser(N, 6)
w_int = [sub_integral_to_uint(i, COEFF_PREC) for i in w]

with open("src/roms/window/coeffs.hex", "w") as f:
    for coeff in w_int:
        f.write(format(coeff, "x"))
        f.write("\n")
