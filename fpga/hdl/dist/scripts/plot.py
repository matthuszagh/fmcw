#!/usr/bin/env python

from matplotlib import pyplot as plt
import numpy as np

y = []
timestep = 1 / 15e6

with open("data_tb.txt", "r") as f:
    for _, line in enumerate(f):
        line = line.strip("\n")
        y.append(int(line))

x = np.linspace(0, len(y) * timestep, len(y))

plt.plot(x, y)
plt.show()
