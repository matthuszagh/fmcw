#!/usr/bin/env python
"""
Plot radar data.
"""

# import os.path
import sys
from enum import IntEnum
import numpy as np
from scipy import signal
from pyqtgraph.Qt import QtGui
import pyqtgraph as pg
import pyqtgraph.exporters
from matplotlib import cm

FFT_LEN = 1024
RAW_LEN = 8000

# number of x points in the plot or hist
PLOT_DOMAIN = 2000
HIST_LEVELS = [0, 100]

DOWNSAMPLE_FACTOR = 20

# precompute filter for better performance
PASS_DB = 0.5
STOP_DB = -40
WEIGHT = [1 / (1 - 10 ** (-PASS_DB / 20)), 1 / (10 ** (STOP_DB / 20))]
TAPS = signal.remez(
    numtaps=120,
    bands=[0, 1e6, 1.5e6, 20e6],
    desired=[1, 0],
    weight=WEIGHT,
    fs=40e6,
    type="bandpass",
)


class DType(IntEnum):
    FFT = 1
    WIND = 2
    FIR = 3
    RAW = 4


class PType(IntEnum):
    TIME = 0
    HIST = 1


class Plot:
    def __init__(self):
        self.plot_type = None
        self.fname = 0
        # initialize Qt
        self.app = QtGui.QApplication([])
        self.win = None
        self.data = None
        self.time = None
        self.xval = 0
        # matplotlib colors
        colormap = cm.get_cmap("CMRmap")
        colormap._init()
        self.colors = (colormap._lut * 255).view(np.ndarray)

    def _initialize_plot(self, data):
        # initialize data arrays
        if data.indata_type == DType.FFT or data.fft:
            if data.indata_type == DType.RAW:
                self.data = np.zeros(
                    (PLOT_DOMAIN, int(RAW_LEN / DOWNSAMPLE_FACTOR / 2))
                )
            else:
                self.data = np.zeros((PLOT_DOMAIN, int(FFT_LEN / 2)))
        else:
            self.data = np.zeros(PLOT_DOMAIN)

        # set start time
        self.time = data.time

        # setup plot gui
        if self.plot_type == PType.TIME:
            self.win = pg.PlotWidget()
        else:
            self.win = pg.GraphicsLayoutWidget()
        self.win.show()

        if self.plot_type == PType.HIST:
            self.win.setWindowTitle("Range Plot")
            self.view = self.win.addViewBox()
            self.view.setAspectLocked(False)
            self.yaxis = pg.AxisItem("left", linkView=self.view)
            # Set initial view bounds
            self.view.enableAutoRange()
            self.img = pg.ImageItem(border="w")
            self.img.setLookupTable(self.colors)
            self.view.addItem(self.img)
        else:
            self.win.setWindowTitle("Time Plot")
            # explicitly setting limits and disabling the autorange
            # facility makes plotting faster
            self.win.setYRange(-100, 100, padding=0)
            self.win.setXRange(0, PLOT_DOMAIN, padding=0)
            self.win.disableAutoRange()

    def update_plot(self, data):
        if self.win is None:
            self._initialize_plot(data)
        # # TODO this is a temporary fix to remove the 500KHz tone. The
        # # proper solution is to fix the hardware.
        # llim = 256
        # ulim = 268
        # for i in range(llim, ulim):
        #     if i < len(data.data[0]):
        #         data.data[0][i] = data.data[0][i - (ulim - llim)]
        if self.plot_type == PType.HIST:
            val = data.data[0]
            if self.xval == PLOT_DOMAIN - 1:
                # save plot to 'plots' dir
                exporter = pg.exporters.ImageExporter(self.img)
                exporter.params.param("width").setValue(
                    1920, blockSignal=exporter.widthChanged
                )
                exporter.params.param("height").setValue(
                    1080, blockSignal=exporter.heightChanged
                )
                exporter.export("plots/" + str(self.fname) + ".png")
                self.fname += 1
                # zero data
                self.data = np.zeros(np.shape(self.data))
                self.xval = 0
            else:
                self.xval += 1
            self.data[self.xval] = val
            self.img.setImage(self.data)
            self.img.setLevels(HIST_LEVELS)
            self.app.processEvents()
        else:
            for val in data.data[0]:
                if self.xval == PLOT_DOMAIN - 1:
                    # save plot to 'plots' dir
                    exporter = pg.exporters.ImageExporter(
                        self.win.getPlotItem()
                    )
                    exporter.params.param("width").setValue(
                        1080, blockSignal=exporter.widthChanged
                    )
                    exporter.params.param("height").setValue(
                        1080, blockSignal=exporter.heightChanged
                    )
                    exporter.export("plots/" + str(self.fname) + ".png")
                    self.fname += 1
                    # zero data
                    self.data = np.zeros(np.shape(self.data))
                    self.xval = 0
                else:
                    self.xval += 1
                self.data[self.xval] = val

                self.win.plot(
                    np.linspace(0, PLOT_DOMAIN - 1, PLOT_DOMAIN),
                    self.data,
                    clear=True,
                )
                self.app.processEvents()


# TODO rename
class DataProc:
    def __init__(self):
        self.data = None
        self.time = 0
        self.indata_type = DType.FFT
        self.fir = True
        self.wind = True
        self.fft = True

    def perform_fft(self):
        # TODO explain why we skip first data point
        full_fft = [
            np.fft.rfft(self.data[0])[1:],
            np.fft.rfft(self.data[1])[1:],
        ]
        self.data = np.zeros(np.shape(full_fft))
        self.data[0] = np.sqrt(
            np.square(np.real(full_fft[0])) + np.square(np.imag(full_fft[0]))
        )
        self.data[1] = np.sqrt(
            np.square(np.real(full_fft[1])) + np.square(np.imag(full_fft[1]))
        )

    def perform_window(self):
        window = np.kaiser(len(self.data[0]), 6)
        self.data[0] = np.multiply(self.data[0], window)
        self.data[1] = np.multiply(self.data[1], window)

    def perform_fir(self):
        filtered = [
            np.convolve(self.data[0], TAPS, "same"),
            np.convolve(self.data[1], TAPS, "same"),
        ]
        filt_downs = [None, None]
        filt_downs[0] = [
            val
            for i, val in enumerate(filtered[0])
            if i % DOWNSAMPLE_FACTOR == 0
        ]
        filt_downs[1] = [
            val
            for i, val in enumerate(filtered[1])
            if i % DOWNSAMPLE_FACTOR == 0
        ]

        self.data = filt_downs

    def process_data(self, cur_type):
        # make this fastest when FPGA does all processing
        if cur_type == DType.FFT:
            return
        elif cur_type == DType.WIND:
            if self.fft:
                self.perform_fft()
            self.process_data(cur_type - 1)
        elif cur_type == DType.FIR:
            if self.wind:
                self.perform_window()
            self.process_data(cur_type - 1)
        elif cur_type == DType.RAW:
            if self.fir:
                self.perform_fir()
            self.process_data(cur_type - 1)


class Monitor:
    def __init__(self):
        self.buf = sys.stdin.buffer
        self.plot = Plot()
        self.data = DataProc()

    def _read_n_bytes(self, n):
        # TODO what should signed be?
        val = int.from_bytes(
            self.buf.read(n), byteorder=sys.byteorder, signed=True
        )
        return val

    def _init_data_arrays(self):
        if self.data.indata_type == DType.RAW:
            self.data.data = np.zeros((2, RAW_LEN))
        elif self.data.indata_type == DType.FIR:
            self.data.data = np.zeros((2, FFT_LEN))
        elif self.data.indata_type == DType.WIND:
            self.data.data = np.zeros((2, FFT_LEN))
        elif self.data.indata_type == DType.FFT:
            self.data.data = np.zeros((2, int(FFT_LEN / 2)))
        else:
            raise ValueError("Invalid FPGA data type")

    def _read_cmd(self):
        plot = self._read_n_bytes(1)
        if plot == 1:
            self.plot.plot_type = PType.HIST
        elif plot == 0:
            self.plot.plot_type = PType.TIME
        else:
            raise ValueError("Invalid plot type")

        self.data.indata_type = self._read_n_bytes(1)

        self._init_data_arrays()

        algos = self._read_n_bytes(1)
        if algos & 1 == 0:
            self.data.fir = False
        if (algos & (1 << 1)) >> 1 == 0:
            self.data.wind = False
        if (algos & (1 << 2)) >> 2 == 0:
            self.data.fft = False

    def _read_data(self):
        self.data.time = self._read_n_bytes(4)
        if self.data.indata_type == DType.FFT:
            for i in range(FFT_LEN):
                if i < FFT_LEN / 2:
                    self.data.data[0][i] = self._read_n_bytes(4)
                else:
                    self._read_n_bytes(4)
        elif (
            self.data.indata_type == DType.WIND
            or self.data.indata_type == DType.FIR
        ):
            for i in range(FFT_LEN):
                self.data.data[0][i] = self._read_n_bytes(4)
            for i in range(FFT_LEN):
                self.data.data[1][i] = self._read_n_bytes(4)
        else:  # 'raw'
            for i in range(RAW_LEN):
                self.data.data[0][i] = self._read_n_bytes(4)
            for i in range(RAW_LEN):
                self.data.data[1][i] = self._read_n_bytes(4)

    def read_packet(self):
        indic = self._read_n_bytes(1)
        if indic == 1:
            self._read_cmd()
            # Call recursively until we get data. There should only be
            # 1 command before data is sent.
            self.read_packet()
        else:
            self._init_data_arrays()
            self._read_data()


if __name__ == "__main__":
    monitor = Monitor()
    while True:
        monitor.read_packet()
        monitor.data.process_data(monitor.data.indata_type)
        monitor.plot.update_plot(monitor.data)
