#!/usr/bin/env python3

import getopt
import sys
import math

from fir_common import *


def help():
    """Print help message."""
    print("""Compute the quantization cost for bit widths in a specified range.""")
    print("Usage: quantization-cost.py [options]")
    print("\t-h")
    print("\t\tDisplay help.\n")
    print("\t-l")
    print("\t\tLower bit width limit. Defaults to 8 bits if none specified.\n")
    print("\t-u")
    print("\t\tUpper bit width limit. Defaults to 24 bits if none specified.\n")


def rms_err(dbl_arr, w):
    """Compute the RMS error of a bit quantization compared to the double
    precision floating point representation."""
    err_acc = 0
    for dbl in dbl_arr:
        err_acc += (dbl - (quantize(dbl, w)/2**w))**2

    return math.sqrt(err_acc)


def main(argv):
    lb = 8
    ub = 24

    try:
        opts, _ = getopt.getopt(argv, "hl:u:")
    except getopt.GetoptError:
        help()
        exit(2)

    for opt, arg in opts:
        if opt == '-h':
            help()
            exit(0)
        elif opt == '-l':
            lb = arg
        elif opt == '-u':
            ub = arg

    if (ub < lb):
        print("Lower bit width must be less than upper bit width.")
        exit(2)

    dbl_file = open("fir_coeffs.dbl", 'r')
    dbl_arr = dbl_file.read().split('\n')
    dbl_arr = list(filter(None, dbl_arr))
    dbl_arr = [float(i) for i in dbl_arr]

    for w in range(lb, ub+1):
        print("{0}: {1:.4f}".format(w, rms_err(dbl_arr, w)))


if __name__ == "__main__":
    main(sys.argv)
