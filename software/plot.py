#!/usr/bin/env python

from pyqtgraph.Qt import QtCore, QtGui
import pyqtgraph as pg
import numpy as np
import os.path

if __name__ == "__main__":
    num_timesteps = 2000

    app = QtGui.QApplication([])

    # Create window with GraphicsView widget
    win = pg.GraphicsLayoutWidget()
    win.show()  # show widget alone in its own window
    win.setWindowTitle("Range Plot")
    view = win.addViewBox()

    view.setAspectLocked(False)

    # Set initial view bounds
    view.enableAutoRange()

    ts = 0
    hist = np.zeros((num_timesteps, 512))
    img = pg.ImageItem(border="w")
    view.addItem(img)

    while True:
        fname = "data/{:05d}.dec".format(ts)
        if os.path.isfile(fname):
            with open("data/{:05d}.dec".format(ts), "r") as f:
                if ts % num_timesteps == 0:
                    hist = np.zeros((num_timesteps, 512))

                hist[ts % num_timesteps] = np.loadtxt(f, usecols=0)

                img.setImage(hist)
                img.setLevels([0, 500])
                app.processEvents()
                ts += 1
        else:
            continue
