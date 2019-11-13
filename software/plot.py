#!/usr/bin/env python

from pyqtgraph.Qt import QtCore, QtGui
import pyqtgraph as pg
import numpy as np

if __name__ == "__main__":
    num_timesteps = 1000

    app = QtGui.QApplication([])

    # Create window with GraphicsView widget
    win = pg.GraphicsLayoutWidget()
    win.show()  # show widget alone in its own window
    win.setWindowTitle("Range Plot")
    view = win.addViewBox()

    view.setAspectLocked(True)

    # Set initial view bounds
    view.enableAutoRange()

    ts = 0
    hist = np.zeros((num_timesteps, 1024))
    img = pg.ImageItem(border="w")
    view.addItem(img)

    while True:
        with open("data/{:05d}.dec".format(ts), "r") as f:
            for _, line in enumerate(f):
                line = line.strip("\n")
                line = line.split()
                fft = int(line[0])
                ctr = int(line[1])
                hist[ts][ctr] = fft

            img.setImage(hist)
            img.setLevels([0, 500])
            app.processEvents()
            ts += 1
