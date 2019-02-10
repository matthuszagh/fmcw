#!/usr/bin/python

import yaml
import math
from fir_common import *

fparams = open("hdl_params.yml", "r")
dat = yaml.safe_load(fparams)

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
f.write('M = {0}, \\\n'.format(M))
f.write('MW = {0}\n'.format(MW))
f.close()
