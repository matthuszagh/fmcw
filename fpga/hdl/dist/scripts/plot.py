#!/usr/bin/env python

import matplotlib.pyplot as plt
import numpy as np


def plot_fft():
    fft = []
    freq_bin = []
    timestep = 1 / 15e6

    with open("data/fft.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            fft.append(val)

    with open("data/fft_ctr.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            freq_bin.append(val)

    x = np.linspace(0, len(y) * timestep, len(y))

    plt.plot(x, y)
    plt.show()


def plot_fft_re():
    y = []
    y2 = []
    with open("data/fft_re.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            y.append(val)

    with open("data/fft_ctr.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            y2.append(val)

    x = np.linspace(0, len(y), len(y))
    xlim = x[0:10000]
    ylim = y[0:10000]
    y2lim = y2[0:10000]
    plt.plot(xlim, ylim)
    plt.plot(xlim, y2lim)
    plt.show()


def plot_fft_in():
    y = []
    y2 = []
    y3 = []
    with open("data/fft_in.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            y.append(val)

    with open("data/fft_en.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            y2.append(500 * val)

    with open("data/fft_sync.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            y3.append(1000 * val)

    x = np.linspace(0, len(y), len(y))
    xlim = x[0:10000]
    ylim = y[0:10000]
    y2lim = y2[0:10000]
    y3lim = y3[0:10000]
    plt.plot(xlim, ylim)
    plt.plot(xlim, y2lim)
    plt.plot(xlim, y3lim)
    plt.show()


def plot_fft_w0_re():
    y = []
    y2 = []
    y3 = []
    y4 = []
    y5 = []
    with open("data/fft_w0_re.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            y.append(val)

    with open("data/fft_en.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            y2.append(50 * val)

    with open("data/fft_sync.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            y3.append(100 * val)

    with open("data/pll_lock.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            y4.append(150 * val)

    with open("data/pll2_lock.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            y5.append(200 * val)

    x = np.linspace(0, len(y), len(y))
    xlim = x[10000:100000]
    ylim = y[10000:100000]
    y2lim = y2[10000:100000]
    y3lim = y3[10000:100000]
    y4lim = y4[10000:100000]
    y5lim = y5[10000:100000]
    plt.plot(xlim, ylim)
    plt.plot(xlim, y2lim)
    plt.plot(xlim, y3lim)
    plt.plot(xlim, y4lim)
    plt.plot(xlim, y5lim)
    plt.show()


def plot_chan_filtered():
    y = []
    with open("data/chan_filtered.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            y.append(val)

    x = np.linspace(0, len(y), len(y))
    xlim = x[0:10000]
    ylim = y[0:10000]
    plt.plot(xlim, ylim)
    plt.show()


def plot_chan_a():
    y = []
    with open("data/chan_a.dec", "r") as f:
        for _, line in enumerate(f):
            line = line.strip("\n")
            val = int(line)
            y.append(val)

    x = np.linspace(0, len(y), len(y))
    xlim = x[0:10000]
    ylim = y[0:10000]
    plt.plot(xlim, ylim)
    plt.show()


if __name__ == "__main__":
    plot_fft_re()
