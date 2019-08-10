#!/usr/bin/env python3

OW = 24

with open("sample.txt", "r") as fin:
    with open("../hdl/tb/fft_r22sdf.hex", "w") as fout:
        for line in fin:
            val = float(line.split()[0])
            if (val >= 0):
                val_int = int(val)
            else:
                val_int = int(2**(OW)+val)
            fout.write("{:X}\n".format(val_int))
