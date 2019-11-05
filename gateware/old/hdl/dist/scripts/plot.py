#!/usr/bin/env python

import pyqtgraph as pg
import numpy as np

with open("plot_data.dec", "r") as f:
    y = []
    for _, line in enumerate(f):
        line = line.strip("\n")
        val = int(line)
        y.append(val)

    # x = np.linspace(0, len(y)-1, len(y))
    pg.plot(y)
    pg.show()
