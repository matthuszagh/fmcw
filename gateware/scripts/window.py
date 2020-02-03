#!/usr/bin/env python
"""
Generate a rom file populated with window coefficients. Ensure the
right number of coefficients is generated and that you use the desired
window function.
"""

from bit import sub_integral_to_uint
import numpy as np

N = 1024
COEFF_PREC = 16

w = np.kaiser(N, 6)
w_int = [sub_integral_to_uint(i, COEFF_PREC) for i in w]

with open("../roms/window/coeffs.hex", "w") as f:
    for coeff in w_int:
        f.write(format(coeff, "x"))
        f.write("\n")
