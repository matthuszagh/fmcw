#!/usr/bin/env python

from matplotlib import pyplot as plt
import numpy as np

y = []
timestep = 1 / 15e6

with open("data.dec", "r") as f:
    for _, line in enumerate(f):
        line = line.strip("\n")
        val = int(line)
        y.append(val)

x = np.linspace(0, len(y) * timestep, len(y))

plt.plot(x, y)
plt.show()
