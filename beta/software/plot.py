#!/usr/bin/env python
import sys
import argparse
import pathlib
from copy import copy
import numpy as np
from scipy import signal
from pyqtgraph.Qt import QtGui
import pyqtgraph as pg
import pyqtgraph.exporters
from pyqtgraph.exporters import ImageExporter

RAW_LEN = 20480
FS = 40e6
PASS_DB = 0.5
STOP_DB = -40
NUMTAPS = 120
BANDS = [0, 0.5e6, 1.0e6, 20e6]
BAND_GAIN = [1, 0]
DOWNSAMPLE = 20
PLOT_DOMAIN = 2000
FFT_LEN = RAW_LEN // DOWNSAMPLE
FFT_RES_LEN = FFT_LEN // 2 + 1
DB_MIN = -60
DB_MAX = -20


def db_arr(indata):
    return 20 * np.log10(indata / np.power(2, 12))


class Plot:
    """
    """

    def __init__(self):
        """
        """
        self.fname = 0
        # initialize Qt
        self.app = QtGui.QApplication([])
        self.win = None
        self.data = None
        self.time = None
        self.xval = 0


class PlotHist(Plot):
    """
    """

    def __init__(self):
        """
        """
        super().__init__()
        self._win = QtGui.QMainWindow()
        # self._win = QtGui.QWidget()
        # self._layout = QtGui.QGridLayout()
        # self._win.setLayout(self._layout)
        self._imv = pg.ImageView(view=pg.PlotItem())
        self.img_view = self._imv.getView()
        self.img_view.invertY(False)
        self.img_view.setLimits(yMin=0, yMax=512)
        self.img_view.getAxis("left").setScale(0.5)
        self._win.setCentralWidget(self._imv)
        # self._layout.addWidget(self._imv, 0, 0)
        self._win.show()

        # self._layout = pg.GraphicsLayoutWidget()
        # self._layout.show()
        self._set_title()
        # self._set_yaxis()
        self._set_hist_colors()
        # self._set_hist_plot()
        self.data = np.zeros((PLOT_DOMAIN, int(FFT_LEN / 2)))

    def update_plot(self, data):
        """
        """
        val = data
        dbval = db_arr(val)
        dbval = np.clip(dbval, DB_MIN, DB_MAX)
        if self.xval == PLOT_DOMAIN - 1:
            self._save_plot()
            self.fname += 1
            self.data = np.zeros(np.shape(self.data))
            self.xval = 0
        else:
            self.xval += 1
        self.data[self.xval] = dbval
        self._imv.setImage(self.data, xvals=[i for i in range(PLOT_DOMAIN)])
        self._imv.setLevels(DB_MIN, DB_MAX)
        self.app.processEvents()

    def _save_plot(self):
        """
        """
        pathlib.Path("plots/").mkdir(parents=True, exist_ok=True)
        # exp = ImageExporter(self._win.scene())
        # exp.export("plots/" + str(self.fname) + ".png")
        self._imv.export("plots/" + str(self.fname) + ".png")

    def _set_title(self):
        """
        """
        self._win.setWindowTitle("Range Plot")

    def _set_yaxis(self):
        """
        """
        self.yaxis = pg.AxisItem("left")
        self._layout.addItem(self.yaxis, 1, 0)

    def _set_hist_colors(self):
        """
        """
        self._imv.setPredefinedGradient("flame")

    def _set_hist_plot(self):
        """
        """
        self.img = pg.ImageItem(border="w")
        self.img.setLookupTable(self.colors)
        viewbox = self._layout.addViewBox(1, 1)
        viewbox.addItem(self.img)


class PlotTime(Plot):
    """
    """

    def __init__(self):
        """
        """
        super().__init__()
        self._win = pg.PlotWidget()
        self._win.setWindowTitle("Time Plot")
        # explicitly setting limits and disabling the autorange
        # facility makes plotting faster
        self._win.setXRange(0, PLOT_DOMAIN, padding=0)
        # self._win.setYRange(-100, 100, padding=0)
        # self._win.disableAutoRange()
        self._win.show()
        self.data = np.zeros(PLOT_DOMAIN)

    def update_plot(self, data):
        """
        """
        for val in data:
            if self.xval == PLOT_DOMAIN - 1:
                # save plot to 'plots' dir
                exporter = pg.exporters.ImageExporter(self._win.getPlotItem())
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

            self._win.plot(
                np.linspace(0, PLOT_DOMAIN - 1, PLOT_DOMAIN),
                self.data,
                clear=True,
            )
            self.app.processEvents()


class PlotSpectrum(Plot):
    """
    """

    def __init__(self, xnum: int):
        """
        """
        super().__init__()
        self._win = pg.PlotWidget()
        self._win.setWindowTitle("Time Plot")
        # explicitly setting limits and disabling the autorange
        # facility makes plotting faster
        self.xnum = xnum
        self._win.setXRange(0, self.xnum, padding=0)
        self._win.setYRange(0, self.xnum, padding=0)
        self._win.disableAutoRange()
        self._win.show()
        self.data = np.zeros(self.xnum)

    def update_plot(self, data):
        """
        """
        self.data = data
        self._win.plot(
            np.linspace(0, self.xnum - 1, self.xnum), self.data, clear=True,
        )
        self.app.processEvents()


def read_sequence(buf) -> np.array:
    """
    """
    raw_arr = np.zeros(RAW_LEN)
    for i in range(RAW_LEN):
        rdbin = buf.read(2)
        if rdbin == b"":
            sys.exit(0)
        else:
            val = int.from_bytes(rdbin, byteorder=sys.byteorder, signed=True)
            # print(rdbin, " ", val)
            raw_arr[i] = val
    return raw_arr


class Proc:
    """
    Data processing.
    """

    choices = ["raw", "fir", "decimate", "window", "fft"]

    def __init__(self, output: str, spectrum: bool, sub_last: bool):
        """
        """
        self.output = self.choices.index(output)
        if self.output > self.choices.index("raw"):
            self._init_fir()
        if self.output > self.choices.index("decimate"):
            self._init_window()
        self.last_seq = np.zeros(RAW_LEN)

        if self.output == self.choices.index("fft"):
            self.spectrum = False
        else:
            self.spectrum = spectrum

        self.sub_last = sub_last

    def _init_fir(self):
        """
        """
        w = [1 / (1 - 10 ** (-PASS_DB / 20)), 1 / (10 ** (STOP_DB / 20))]
        self.taps = signal.remez(
            numtaps=NUMTAPS,
            bands=BANDS,
            desired=BAND_GAIN,
            weight=w,
            fs=FS,
            type="bandpass",
        )

    def _init_window(self):
        """
        """
        self.window_coeffs = np.kaiser(FFT_LEN, 6)

    def process_sequence(self, seq: np.array) -> np.array:
        """
        """
        if self.sub_last:
            new_seq = np.subtract(seq, self.last_seq)
            self.last_seq = copy(seq)
            seq = new_seq

        i = 0
        proc_func = [
            self.perform_fir,
            self.perform_decimate,
            self.perform_window,
            self.perform_fft,
        ]
        while i < self.output:
            seq = proc_func[i](seq)
            i += 1

        if self.spectrum:
            seq = np.abs(np.fft.rfft(seq))

        return seq

    def perform_fir(self, seq: np.array) -> np.array:
        """
        """
        fir = np.convolve(seq, self.taps, mode="same")
        return fir

    def perform_decimate(self, seq: np.array) -> np.array:
        """
        """
        dec_arr = [seq[i] for i in range(len(seq)) if i % DOWNSAMPLE == 0]
        return dec_arr

    def perform_window(self, seq: np.array) -> np.array:
        """
        """
        window = np.multiply(seq, self.window_coeffs)
        return window

    def perform_fft(self, seq: np.array) -> np.array:
        """
        """
        fft = np.fft.rfft(seq)
        return np.abs(fft)[1:]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Process and plot radar data."
    )
    parser.add_argument("output", choices=Proc.choices, default="fft")
    parser.add_argument(
        "-s",
        "--spectrum",
        action="store_const",
        const=True,
        dest="spectrum",
        help=(
            "Display the output as a frequency spectrum. This has no "
            "effect if fft is the chosen output."
        ),
    )
    parser.add_argument(
        "-b",
        "--background",
        action="store_const",
        const=True,
        dest="background",
        help=(
            "Subtract last sweep from current sweep. This removes "
            "the signal background."
        ),
    )
    args = parser.parse_args()

    if args.output == "fft":
        plot = PlotHist()
    elif args.spectrum:
        out = args.output
        if out == "raw" or out == "fir":
            xnum = RAW_LEN // 2 + 1
        else:
            xnum = FFT_RES_LEN
        plot = PlotSpectrum(xnum)
    else:
        plot = PlotTime()

    proc = Proc(
        output=args.output, spectrum=args.spectrum, sub_last=args.background
    )

    with sys.stdin.buffer as buf:
        while True:
            raw_arr = read_sequence(buf)
            arr = proc.process_sequence(raw_arr)
            plot.update_plot(arr)
