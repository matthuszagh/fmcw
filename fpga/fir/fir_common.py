#!/usr/bin/env python3

import math


def quantize(dbl, w):
    """Quantize a double precision floating point for a given bit
    width."""
    return round(dbl*(2**w))


def compute_bits(iw, fname):
    """Compute number of bits needed to hold output for a given input
    width. Use the actual impulse values rather than log2(NTAPS) guard
    bits, which is usually excessive.

    """
    max_input = 2**(iw-1)-1
    acc = 0

    f = open(fname, "r")
    dbl_arr = f.read().split('\n')
    dbl_arr = list(filter(None, dbl_arr))
    dbl_arr = [float(i) for i in dbl_arr]

    for dbl in dbl_arr:
        acc += abs(max_input*dbl)

    return math.ceil(math.log2(acc)+1)
