#!/usr/bin/env python

import pyqtgraph as pg
import numpy as np
from libdigital.tools.fir import FIR

num_cols = 2
# fir = FIR(
#     numtaps=120,
#     bands=[0, 0.95e6, 1e6, 20e6],
#     band_gain=[1, 0],
#     fs=40e6,
#     pass_db=0.5,
#     stop_db=-40,
# )

with open("plot.dec", "r") as f:
    y_cont = []
    for col in range(num_cols):
        y_cont.append([])
    for _, line in enumerate(f):
        line = line.strip("\n")
        line = line.split()
        y_inner = []
        for col in range(num_cols):
            y_cont[col].append(int(line[col]))

    # for col in range(num_cols):
    # out_pre_dec = np.convolve(y_cont[0], fir.taps)
    # # use convergent rounding
    # outputs = [
    #     out_pre_dec[i]
    #     # int(np.around(out_pre_dec[i]))
    #     for i in range(len(out_pre_dec))
    #     if i % 20 == 0
    # ]

    # with open("fir_out.dec", "w") as fout:
    #     for out in outputs:
    #         fout.write("{}\n".format(out))

    x = np.linspace(0, len(y_cont[0]) - 1, len(y_cont[0]))
    # x2 = np.linspace(0, len(y_cont[0]) - 1, len(outputs))
    plt = pg.plot()
    for i in range(num_cols):
        plt.plot(x, y_cont[i], pen=(i, num_cols))
    # plt.plot(x2, outputs)
    pg.show()
