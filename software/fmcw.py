#!/usr/bin/env python
from __future__ import annotations
from time import clock_gettime, CLOCK_MONOTONIC
import sys
from enum import IntEnum, auto
from typing import Union, Optional, Callable, List, Tuple
from pathlib import Path
from shutil import rmtree
from multiprocessing import Process, Pipe
from multiprocessing.connection import Connection
from queue import Queue
import numpy as np
from pyqtgraph.Qt import QtGui
import pyqtgraph as pg
from scipy import signal
from device import Device

BITMODE_SYNCFF = 0x40
CHUNKSIZE = 0x10000
SIO_RTS_CTS_HS = 0x1 << 8
START_FLAG = 0xFF
STOP_FLAG = 0x8F
RAW_LEN = 20480
FS = 40e6
TSWEEP = 1e-3
BANDWIDTH = 300e6
PASS_DB = 0.5
STOP_DB = -40
NUMTAPS = 120
BANDS = [0, 0.5e6, 1.0e6, 20e6]
BAND_GAIN = [1, 0]
DECIMATE = 20
DECIMATED_LEN = RAW_LEN // DECIMATE
BYTE_BITS = 8
ADC_BITS = 12
FIR_BITS = 13
WINDOW_BITS = 13
FFT_BITS = FIR_BITS + 1 + int(np.ceil(np.log2(DECIMATED_LEN)))
# TODO should be configuration option
HIST_RANGE = 3000
# dB min and max if no other value is set
DB_MIN = -140
DB_MAX = 0
DIST_INIT = 235


def dist_to_freq(dist: float, bw: float, ts: float) -> float:
    """
    """
    return int(2 * dist * bw / (299792458 * ts))


FREQ_INIT = dist_to_freq(DIST_INIT, BANDWIDTH, TSWEEP)


def freq_to_dist(freq: float, bw: float, ts: float) -> float:
    """
    """
    return int(299792458 * freq * ts / (2 * bw))


def _reverse_bits(val: int, nbits: int) -> int:
    """
    """
    i = 0
    newval = 0
    while i < nbits:
        mask = 0x1 << i
        newval |= ((mask & val) >> i) << (nbits - 1 - i)
        i += 1

    return newval


HORIZONTAL_LINES = "----------\n"


class Data(IntEnum):
    RAW = 0
    FIR = 1
    DECIMATE = 2
    WINDOW = 3
    FFT = 4


def data_to_fpga_output(data: Data) -> str:
    """
    """
    if data == Data.RAW:
        return "RAW"
    elif data == Data.DECIMATE:
        return "FIR"
    elif data == Data.WINDOW:
        return "WINDOW"
    else:
        return "FFT"


def data_from_str(strval: str) -> Data:
    """
    """
    strval = strval.lower()
    if strval == "raw" or strval == "r":
        return Data.RAW
    elif strval == "fir" or strval == "fi":
        return Data.FIR
    elif strval == "decimate" or strval == "d":
        return Data.DECIMATE
    elif strval == "window" or strval == "w":
        return Data.WINDOW
    elif strval == "fft" or strval == "ff":
        return Data.FFT

    raise RuntimeError("Invalid Data string.")


def data_sweep_len(data: Data) -> int:
    """
    """
    if data <= Data.FIR:
        return RAW_LEN
    else:
        return DECIMATED_LEN


def spectrum_len(data: Data) -> int:
    """
    """
    return data_sweep_len(data) // 2 + 1


def nyquist_freq(data: Data) -> float:
    """
    """
    if data == Data.RAW or data == Data.FIR:
        return FS // 2
    return FS // 2 // DECIMATE


# TODO: this should be in sync with the FPGA configuration. Currently,
# bit widths need to set twice independently.
def data_nbits(data: Data) -> int:
    """
    """
    if data == Data.RAW:
        return ADC_BITS
    if data == Data.DECIMATE:
        return FIR_BITS
    if data == Data.WINDOW:
        return WINDOW_BITS
    if data == Data.FFT:
        return FFT_BITS

    raise ValueError("Invalid Data value.")


def pow2ceil(val: int) -> int:
    """
    """
    res = 1
    while val > res:
        res *= 2
    return res


def data_nbytes(nbits: int) -> int:
    """
    """
    nbytes = nbits // 8
    if nbits % nbytes != 0:
        nbytes += 1
    return pow2ceil(nbytes)


def data_nflags(data: Data) -> int:
    """
    The number of start and stop flag bytes for a payload with a given
    number of bits.  Each sample is MSB-padded with 0s until it is
    byte-aligned.  The MSB of the sample + padding is guaranteed to be
    zero.  That is, at least 1 0-bit is padded to each sample.  This
    allows us to distinguish a start or stop flag from a sample.  The
    flag length is therefore equal to the number of bytes of the
    sample + padding.
    """
    sample_bits = data_nbits(data)
    if data == Data.FFT:
        sample_bits *= 2
    nbytes = sample_bits // 8 + 1
    return pow2ceil(nbytes)


def write(txt: str, newline: bool = True):
    """
    """
    sys.stdout.write(txt)
    if newline:
        sys.stdout.write("\n")
    sys.stdout.flush()


def number_from_array(arr: List[np.uint8], nbits: int) -> int:
    """
    """
    uval = int.from_bytes(arr, byteorder="big")
    mask = 2 ** (nbits - 1)
    sval = -(uval & mask) + (uval & ~mask)
    return sval


def path_is_subdir(path: Path) -> bool:
    """
    """
    cwd = Path.cwd().as_posix()
    return cwd == path.as_posix()[: len(cwd)] and not cwd == path.as_posix()


def subdivide_range(rg: int, divider: int) -> List[Tuple[int, int]]:
    """
    """
    nbins = rg // divider
    if not rg % divider == 0:
        nbins += 1

    ranges = []
    last_upper = 0
    for i in range(nbins - 1):
        ranges.append((last_upper, last_upper + divider))
        last_upper += divider

    ranges.append((last_upper, rg - 1))
    return ranges


def db_arr(indata, maxval, db_min, db_max):
    """
    Convert an array of input data giving amplitude values to the
    full-scale decibel equivalent. Additionally, clip the results to a
    desired range.

    :param indata: Input array of amplitude values.
    :param maxval: Maximum amplitude denoting the full-scale value.
    :param db_min: Minimum dB value to clip to.
    :param db_max: Maximum dB value to clip to.
    """
    arr = 20 * np.log10(indata / maxval)
    return np.clip(arr, db_min, db_max)


def dbin(fs: float, tsweep: float, nsample: int, bandwidth: float) -> float:
    """
    Distance (in m) for each DFT frequency bin.
    """
    fbin = fs / nsample
    d = 299792458 * tsweep * fbin / (2 * bandwidth)
    return d


def plot_rate(nsweep: int, sec: float) -> str:
    """
    :param nsweep: Number of complete sweeps.
    :param sec: Total plot duration in seconds.
    """
    return "Plot rate     : {} sweeps/s".format(int(round(nsweep / sec)))


def usb_bandwidth(nbytes: int, sec: float) -> str:
    """
    :param nbytes: Total number of bytes (including headers and
        padding) transmitted over USB channel.
    :param sec: Total plot duration in seconds.
    """
    bwidth = nbytes / sec
    for unit in ["B", "kB", "MB", "GB"]:
        if bwidth < 10 ** 3:
            return "USB Bandwidth : {} {}/s\n".format(round(bwidth, 3), unit)
        bwidth /= 10 ** 3

    return "USB Bandwidth : {} GB/s\n".format(round(bwidth, 3))


def avg_value(avg: float) -> str:
    """
    """
    return "Average Value : {:.2f}".format(avg)


def sweep_total_bytes(fpga_output: Data) -> int:
    """
    """
    sample_bits = data_nbits(fpga_output)
    if fpga_output == Data.FFT:
        sample_bits *= 2

    sample_bytes = data_nbytes(sample_bits)
    sweep_len = data_sweep_len(fpga_output)
    flag_bytes = data_nflags(fpga_output)
    return sample_bytes * sweep_len + 2 * flag_bytes


class PlotType(IntEnum):
    TIME = auto()
    SPECTRUM = auto()
    HIST = auto()


def plot_type_from_str(strval: str) -> PlotType:
    """
    """
    strval = strval.lower()
    if strval == "time" or strval == "t":
        return PlotType.TIME
    elif strval == "spectrum" or strval == "s":
        return PlotType.SPECTRUM
    elif strval == "hist" or strval == "h":
        return PlotType.HIST

    raise RuntimeError("Invalid Data string.")


class Plot:
    """
    """

    def __init__(self):
        """
        """
        self._ptype = None
        self._output = None
        self._app = QtGui.QApplication([])
        self._data = None
        self.db_min = DB_MIN
        self.db_max = DB_MAX
        self.plot_path = None
        self.tstart = None
        self.tplot_start = None
        self.tcurrent = None
        # min and max data bins
        self.min_bin = None
        self.max_bin = None
        # minimum axis value for spectrum and hist plots
        self.min_axis_val = None
        # maximum axis value for spectrum and hist plots
        self.max_axis_val = None
        # records saved plot number
        self._fname = 0

    @property
    def ptype(self) -> PlotType:
        """
        """
        return self._ptype

    @ptype.setter
    def ptype(self, newval: Data):
        """
        """
        # if self._output is None:
        #     raise RuntimeError("Must set output type before plot type.")

        # if self._ptype is not None:
        #     self._close_plot()

        self._ptype = newval

    @property
    def output(self) -> Data:
        """
        """
        return self._output

    @ptype.setter
    def output(self, newval: Data):
        """
        """
        self._output = newval

    def add_sweep(self, sweep: np.array) -> None:
        """
        Plot the next sweep of data.
        """
        if self._ptype is None:
            raise ValueError("Must call set_type before adding sweeps.")

        if self._ptype == PlotType.TIME:
            self._add_time_sweep(sweep)
        elif self._ptype == PlotType.SPECTRUM:
            self._add_spectrum_sweep(sweep)
        else:
            self._add_hist_sweep(sweep)

    def initialize_plot(self) -> None:
        """
        """
        self._fname = 0
        if self._ptype == PlotType.TIME:
            self._data = np.zeros(data_sweep_len(self._output))
            self._initialize_time_plot()
        elif self._ptype == PlotType.SPECTRUM:
            self._data = np.zeros(self.max_bin - self.min_bin)
            self._initialize_spectrum_plot()
        elif self._ptype == PlotType.HIST:
            self._data = np.zeros((HIST_RANGE, self.max_bin - self.min_bin))
            self._initialize_hist_plot()
        else:
            raise ValueError("Invalid plot type.")

        self.tstart = clock_gettime(CLOCK_MONOTONIC)

    def _initialize_time_plot(self) -> None:
        """
        """
        self._win = QtGui.QMainWindow()
        self._plt = pg.PlotWidget()
        self._plt.setWindowTitle("Time Plot (" + self._output.name + ")")
        self._plt.setXRange(0, self._data.shape[0])
        self._win.setCentralWidget(self._plt)
        self._win.show()

    def _initialize_spectrum_plot(self) -> None:
        """
        """
        self._win = QtGui.QMainWindow()
        self._plt = pg.PlotWidget()
        self._plt.setWindowTitle("Spectrum Plot (" + self._output.name + ")")
        self._plt.getAxis("bottom").setTicks(self._freq_dist_ticks())
        self._plt.setYRange(self.db_min, self.db_max)
        self._win.setCentralWidget(self._plt)
        self._win.show()

    def _initialize_hist_plot(self) -> None:
        """
        """
        self._xval = 0
        self._tvals = []
        self._win = QtGui.QMainWindow()
        self._imv = pg.ImageView(view=pg.PlotItem())
        self._img_view = self._imv.getView()
        self._img_view.invertY(False)
        self._img_view.setAspectLocked(lock=False)
        self._img_view.getAxis("left").setTicks(self._freq_dist_ticks())
        self._imv.setLevels(self.db_min, self.db_max)
        self._win.setCentralWidget(self._imv)
        self._win.show()
        self._win.setWindowTitle(
            "Range-Time Histogram (" + self._output.name + ")"
        )
        self._imv.setPredefinedGradient("flame")
        hist_widget = self._imv.getHistogramWidget()
        hist_widget.region.setBounds([self.db_min, self.db_max])
        # TODO available in v0.11 (I think this is the correct method)
        # hist_widget.region.setSpan([self.db_min, self.db_max])

    def _close_plot(self) -> None:
        """
        """
        self._win.close()

    def _add_time_sweep(self, sweep: np.array) -> None:
        """
        """
        # makes the update much faster
        ranges = subdivide_range(self._data.shape[0], len(sweep) // 200)
        for rg in ranges:
            self._data[rg[0] : rg[1]] = sweep[rg[0] : rg[1]]
            self._win.disableAutoRange()
            self._win.plot(
                np.linspace(0, self._data.shape[0] - 1, self._data.shape[0]),
                self._data,
                clear=True,
            )
            self._win.autoRange()
            self._app.processEvents()

        if self._save_plotsp():
            self._save_plot()

        self._data = np.zeros(self._data.shape)

    def _add_spectrum_sweep(self, sweep: np.array) -> None:
        """
        """
        self._plt.plot(
            np.linspace(0, self._data.shape[0] - 1, self._data.shape[0]),
            sweep,
            clear=True,
        )
        self._app.processEvents()
        if self._save_plotsp():
            self._save_plot()

    def _add_hist_sweep(self, sweep: np.array) -> None:
        """
        """
        self._data[self._xval] = sweep
        self._tvals.append(clock_gettime(CLOCK_MONOTONIC) - self.tstart)
        self._img_view.getAxis("bottom").setTicks(self._time_ticks())
        xrg = self._data.shape[0]
        self._imv.setImage(
            self._data,
            xvals=[i for i in range(xrg)],
            autoRange=False,
            autoHistogramRange=False,
        )

        # speeds up bandwidth somewhat by reducing the burden of
        # updating the plot.
        if self._xval % 5 == 0:
            self._app.processEvents()

        self._xval += 1
        if self._xval == xrg:
            if self._save_plotsp():
                self._save_plot()
            self._data = np.zeros(np.shape(self._data))
            self._xval = 0
            self._tvals = []

    def _time_ticks(self) -> List[List[Tuple[int, float]]]:
        """
        X-Axis ticks for hist plot.
        """
        ret = []
        tval_len = len(self._tvals)
        i = 0
        while i < tval_len:
            ret.append((i, "{:.0f}".format(self._tvals[i])))
            i += HIST_RANGE // 10
        return [ret]

    def _freq_dist_ticks(self) -> List[List[Tuple[int, float]]]:
        """
        """
        ret = []
        slope = (self.max_axis_val - self.min_axis_val) / (
            self.max_bin - self.min_bin
        )
        approx_num_ticks = 20
        rg = self.max_axis_val - self.min_axis_val
        inc = int(10 ** np.round(np.log10((rg / approx_num_ticks))))
        if self.min_axis_val <= inc:
            first_act_val = inc
        else:
            inc_val = inc
            while inc_val < self.min_axis_val:
                inc_val += inc
            first_act_val = inc_val

        act_vals = np.arange(first_act_val, self.max_axis_val, inc)
        bin_vals = [int(np.round(act_val / slope)) for act_val in act_vals]
        bin_vals = np.subtract(bin_vals, self.min_bin)

        for i, j in zip(bin_vals, act_vals):
            ret.append((i, "{:.3g}".format(j)))

        return [ret]

    def _save_plot(self) -> None:
        """
        """
        # diffs = np.diff(self._tvals)
        # for diff in diffs:
        #     print(diff)
        pixmap = QtGui.QPixmap(self._win.size())
        self._win.render(pixmap)
        plot_dir = self.plot_path.as_posix()
        if not plot_dir[-1] == "/":
            plot_dir += "/"
        pixmap.save(plot_dir + str(self._fname) + ".png")
        self._fname += 1

    def _save_plotsp(self) -> bool:
        """
        True if plots should be saved.
        """
        if not self.plot_path == Path.cwd():
            return True


class Parameter:
    """
    """

    def __init__(
        self,
        name: str,
        number: int,
        getter: Callable[[bool], Parameter],
        setter: Callable[[str], None],
        possible: Callable[[], str],
        init: str,
    ):
        """
        """
        self.name = name
        self.number = number
        self.getter = getter
        self.setter = setter
        self.possible = possible
        self.setter(init)

    def display(self, name_width: int) -> str:
        """
        """
        return "{:{width}} : {value}\n".format(
            self.name, width=name_width, value=self.getter(strval=True)
        )

    def display_number_menu(self) -> str:
        """
        """
        return "{}. {}".format(self.number, self.name)


class Configuration:
    """
    """

    def __init__(self, plot: Plot, proc: Proc):
        """
        """
        self.plot = plot
        self.proc = proc
        self._param_ctr = 0

        # parameter variables
        self._fpga_output = None
        self._display_output = None
        self.log_file = None
        self.time = None
        self.ptype = None
        self.db_min = None
        self.db_max = None
        self.plot_dir = None
        self.sub_last = None
        self.channel = None
        self.adf_fstart = None
        self.adf_bandwidth = None
        self.adf_tsweep = None
        self.adf_tdelay = None
        self.min_freq = None
        self.max_freq = None
        self.min_dist = None
        self.max_dist = None
        self.spectrum_axis = None
        self.report_avg = None
        self.params = [
            Parameter(
                name="FPGA output",
                number=self._get_inc_ctr(),
                getter=self._get_fpga_output,
                setter=self._set_fpga_output,
                possible=self._fpga_output_possible,
                init="RAW",
            ),
            Parameter(
                name="display output",
                number=self._get_inc_ctr(),
                getter=self._get_display_output,
                setter=self._set_display_output,
                possible=self._display_output_possible,
                init="FFT",
            ),
            Parameter(
                name="log file",
                number=self._get_inc_ctr(),
                getter=self._get_log_file,
                setter=self._set_log_file,
                possible=self._log_file_possible,
                init="",
            ),
            Parameter(
                name="capture time (s)",
                number=self._get_inc_ctr(),
                getter=self._get_time,
                setter=self._set_time,
                possible=self._time_possible,
                init="35",
            ),
            Parameter(
                name="plot type",
                number=self._get_inc_ctr(),
                getter=self._get_plot_type,
                setter=self._set_plot_type,
                possible=self._plot_type_possible,
                init="hist",
            ),
            Parameter(
                name="dB min",
                number=self._get_inc_ctr(),
                getter=self._get_db_min,
                setter=self._set_db_min,
                possible=self._db_min_possible,
                init="-120",
            ),
            Parameter(
                name="dB max",
                number=self._get_inc_ctr(),
                getter=self._get_db_max,
                setter=self._set_db_max,
                possible=self._db_max_possible,
                init="-20",
            ),
            Parameter(
                name="plot save dir",
                number=self._get_inc_ctr(),
                getter=self._get_plot_dir,
                setter=self._set_plot_dir,
                possible=self._plot_dir_possible,
                init="plots",
            ),
            Parameter(
                name="subtract last",
                number=self._get_inc_ctr(),
                getter=self._get_sub_last,
                setter=self._set_sub_last,
                possible=self._sub_last_possible,
                init="true",
            ),
            Parameter(
                name="Receiver channel",
                number=self._get_inc_ctr(),
                getter=self._get_channel,
                setter=self._set_channel,
                possible=self._channel_possible,
                init="B",
            ),
            Parameter(
                name="ADF start frequency (Hz)",
                number=self._get_inc_ctr(),
                getter=self._get_adf_fstart,
                setter=self._set_adf_fstart,
                possible=self._adf_fstart_possible,
                init="5.6e9",
            ),
            Parameter(
                name="ADF bandwidth (Hz)",
                number=self._get_inc_ctr(),
                getter=self._get_adf_bandwidth,
                setter=self._set_adf_bandwidth,
                possible=self._adf_bandwidth_possible,
                init="300e6",
            ),
            Parameter(
                name="ADF sweep time (s)",
                number=self._get_inc_ctr(),
                getter=self._get_adf_tsweep,
                setter=self._set_adf_tsweep,
                possible=self._adf_tsweep_possible,
                init="1e-3",
            ),
            Parameter(
                name="ADF delay time (s)",
                number=self._get_inc_ctr(),
                getter=self._get_adf_tdelay,
                setter=self._set_adf_tdelay,
                possible=self._adf_tdelay_possible,
                init="2e-3",
            ),
            Parameter(
                name="Min Plotting Frequency (Hz)",
                number=self._get_inc_ctr(),
                getter=self._get_min_freq,
                setter=self._set_min_freq,
                possible=self._min_freq_possible,
                init="0",
            ),
            Parameter(
                name="Max Plotting Frequency (Hz)",
                number=self._get_inc_ctr(),
                getter=self._get_max_freq,
                setter=self._set_max_freq,
                possible=self._max_freq_possible,
                init=str(FREQ_INIT),
            ),
            Parameter(
                name="Min Plotting Distance (m)",
                number=self._get_inc_ctr(),
                getter=self._get_min_dist,
                setter=self._set_min_dist,
                possible=self._min_dist_possible,
                init="0",
            ),
            Parameter(
                name="Max Plotting Distance (m)",
                number=self._get_inc_ctr(),
                getter=self._get_max_dist,
                setter=self._set_max_dist,
                possible=self._max_dist_possible,
                init=str(DIST_INIT),
            ),
            Parameter(
                name="Dist/Freq Axis",
                number=self._get_inc_ctr(),
                getter=self._get_spectrum_axis,
                setter=self._set_spectrum_axis,
                possible=self._spectrum_axis_possible,
                init="dist",
            ),
            Parameter(
                name="Report Average",
                number=self._get_inc_ctr(),
                getter=self._get_report_avg,
                setter=self._set_report_avg,
                possible=self._report_avg_possible,
                init="false",
            ),
        ]
        self._param_name_width = self._max_param_name_width()

    def display(self) -> str:
        """
        """
        display_str = "Configuration:\n" + HORIZONTAL_LINES
        for param in self.params:
            display_str += "{:{width}} : ".format(
                param.name, width=self._param_name_width
            )
            display_str += param.getter(strval=True)
            display_str += "\n"

        return display_str

    def display_number_menu(self) -> str:
        """
        """
        display_str = (
            "Set options (enter the corresponding number):\n"
            + HORIZONTAL_LINES
        )
        for param in self.params:
            display_str += param.display_number_menu()
            display_str += "\n"

        return display_str

    def param_for_number(self, number: int) -> Parameter:
        """
        """
        for param in self.params:
            if number == param.number:
                return param

        raise RuntimeError("Invalid Parameter number.")

    def logp(self) -> bool:
        """
        True if data should be logged.  False otherwise.  This simply
        checks that log file is a non-empty path.
        """
        # The empty string resolves to the current working directory.
        return not self.log_file.is_dir()

    def _get_inc_ctr(self):
        """
        """
        ret = self._param_ctr
        self._param_ctr += 1
        return ret

    def _set_fpga_output(self, newval: str):
        """
        """
        newdata = data_from_str(newval)
        if newdata == Data.FIR:
            self._fpga_output = Data.DECIMATE
        else:
            self._fpga_output = newdata

        self.proc.indata = self._fpga_output

    def _get_fpga_output(self, strval: bool = False):
        """
        """
        if strval:
            return self._fpga_output.name
        return self._fpga_output

    def _fpga_output_possible(self) -> str:
        """
        """
        return "{RAW, DECIMATE, WINDOW, FFT} (case insensitive)"

    def _check_fpga_output(self) -> bool:
        """
        """
        if self._fpga_output > self._display_output:
            write(
                "Display data cannot be from a processing stage that "
                "preceeds FPGA output data."
            )
            return False
        return True

    def _set_display_output(self, newval: str):
        """
        """
        newdata = data_from_str(newval)
        self._display_output = newdata
        self.proc.output = self._display_output
        self.plot.output = self._display_output

    def _get_display_output(self, strval: bool = False):
        """
        """
        if strval:
            return self._display_output.name
        return self._display_output

    def _display_output_possible(self) -> str:
        """
        """
        return "{RAW, FIR, DECIMATE, WINDOW, FFT} (case insensitive)"

    def _check_display_output(self) -> bool:
        """
        """
        return True

    def _set_log_file(self, newval: str):
        """
        """
        self.log_file = Path(newval).resolve()

    def _get_log_file(self, strval: bool = False):
        """
        """
        if strval:
            return self.log_file.as_posix()
        return self.log_file

    def _log_file_possible(self) -> str:
        """
        """
        return "Any valid file path."

    def _check_log_file(self):
        """
        """
        return True

    def _set_time(self, newval: str):
        """
        """
        multiplier = 1
        if newval[-1] == "s":
            newval = newval[:-1]
        elif newval[-1] == "m":
            newval = newval[:-1]
            multiplier *= 60
        elif newval[-1] == "h":
            newval = newval[:-1]
            multiplier *= 60 ** 2
        elif newval[-1] == "d":
            newval = newval[:-1]
            write("Time set to days. Are you sure this is correct?")
            multiplier *= 60 ** 2 * 24

        timeval = int(newval)
        self.time = int(timeval * multiplier)

    def _get_time(self, strval: bool = False):
        """
        """
        if strval:
            return str(self.time)
        return self.time

    def _time_possible(self) -> str:
        """
        """
        return (
            "Integer representing time. s, m, h, d can be appended \n"
            "for seconds, minutes, hours or days if desired "
            "(defaults to seconds if omitted)."
        )

    def _check_time(self) -> bool:
        """
        """
        return True

    def _get_plot_type(self, strval: bool = False):
        """
        """
        if strval:
            return self.ptype.name
        return self.ptype

    def _set_plot_type(self, newval: str):
        """
        """
        ptype = plot_type_from_str(newval)
        self.ptype = ptype
        self.plot.ptype = self.ptype
        if self.ptype == PlotType.SPECTRUM or self.ptype == PlotType.HIST:
            self.proc.spectrum = True
        else:
            self.proc.spectrum = False

    def _plot_type_possible(self) -> str:
        """
        """
        return "{TIME (except FFT output), SPECTRUM, HIST} (case insensitive)"

    def _check_plot_type(self) -> bool:
        """
        """
        if self._fpga_output == Data.FFT and self.ptype == PlotType.TIME:
            return False
        return True

    def _get_db_min(self, strval: bool = False):
        """
        """
        if strval:
            if self.db_min is None:
                return "None"
            return str(self.db_min)
        return self.db_min

    def _set_db_min(self, newval: Optional[str]):
        """
        """
        if newval is None:
            self.db_min = DB_MIN
        else:
            self.db_min = float(newval)
        self.plot.db_min = self.db_min
        self.proc.db_min = self.db_min

    def _db_min_possible(self) -> str:
        """
        """
        return "Any float or None, in which case no minimum clipping will be performed."

    def _check_db_min(self) -> bool:
        """
        """
        return True

    def _get_db_max(self, strval: bool = False):
        """
        """
        if strval:
            if self.db_max is None:
                return "None"
            return str(self.db_max)
        return self.db_max

    def _set_db_max(self, newval: Optional[str]):
        """
        """
        if newval is None:
            self.db_max = DB_MAX
        self.db_max = float(newval)
        self.plot.db_max = self.db_max
        self.proc.db_max = self.db_max

    def _db_max_possible(self) -> str:
        """
        """
        return "Any float or None, in which case no maximum clipping will be performed."

    def _check_db_max(self) -> bool:
        """
        """
        if self.db_max is None or self.db_min is None:
            return True
        if self.db_max > self.db_min:
            return True
        return False

    def _get_plot_dir(self, strval: bool = False):
        """
        """
        if strval:
            return self.plot_dir.as_posix()
        return self.plot_dir

    def _set_plot_dir(self, newval: str):
        """
        """
        self.plot_dir = Path(newval).resolve()
        self.plot.plot_path = self.plot_dir

    def _plot_dir_possible(self) -> str:
        """
        """
        return (
            "Any valid subdirectory path. If the directory already "
            "exists, it will be emptied before new plots are added. "
            "If it doesn't exist, it will be created."
        )

    def _check_plot_dir(self) -> bool:
        """
        """
        if self.plot_dir == Path.cwd():
            return True

        if not path_is_subdir(self.plot_dir):
            return False

        if self.plot_dir.exists():
            rmtree(self.plot_dir)

        self.plot_dir.mkdir(parents=True)
        return True

    def _get_sub_last(self, strval: bool = False):
        """
        """
        if strval:
            if self.sub_last:
                return "True"
            return "False"
        return self.sub_last

    def _set_sub_last(self, newval: str):
        """
        """
        newval_lower = newval.lower()
        if newval_lower == "true" or newval_lower == "t":
            self.sub_last = True
        elif newval_lower == "false" or newval_lower == "f":
            self.sub_last = False
        else:
            print(
                "Invalid value for subtract last. Setting it to False. "
                "Please reconfigure it with a permissible entry."
            )
            self.sub_last = False

        self.proc.sub_last = self.sub_last

    def _sub_last_possible(self) -> str:
        """
        """
        return "True or false (case-insensitive)"

    def _check_sub_last(self) -> bool:
        """
        """
        return True

    def _get_channel(self, strval: bool = False):
        """
        """
        if strval:
            if self.channel:
                return self.channel
            return "None"
        return self.channel

    def _set_channel(self, newval: str):
        """
        """
        if newval.lower() == "a":
            self.channel = "A"
        elif newval.lower() == "b":
            self.channel = "B"
        else:
            print(
                "Invalid channel. Setting it to channel B. Please "
                "reconfigure it with a permissible entry."
            )
            self.channel = "B"

    def _channel_possible(self) -> str:
        """
        """
        return "A or B (case-insensitive)"

    def _check_channel(self) -> bool:
        """
        """
        return True

    def _get_adf_fstart(self, strval: bool = False):
        """
        """
        if strval:
            if self.adf_fstart:
                return str(self.adf_fstart)
            else:
                return "None"
        return self.adf_fstart

    def _set_adf_fstart(self, newval: str):
        """
        """
        self.adf_fstart = float(newval)

    def _adf_fstart_possible(self) -> str:
        """
        """
        return "5.3-5.6GHz"

    def _check_adf_fstart(self) -> bool:
        """
        """
        return True

    def _get_adf_bandwidth(self, strval: bool = False):
        """
        """
        if strval:
            if self.adf_bandwidth:
                return str(self.adf_bandwidth)
            else:
                return "None"
        return self.adf_bandwidth

    def _set_adf_bandwidth(self, newval: str):
        """
        """
        self.adf_bandwidth = float(newval)
        if not self.adf_tsweep is None:
            if not self.min_freq is None:
                self.min_dist = freq_to_dist(
                    self.min_freq, self.adf_bandwidth, self.adf_tsweep
                )
            if not self.max_freq is None:
                self.max_dist = freq_to_dist(
                    self.max_freq, self.adf_bandwidth, self.adf_tsweep
                )

    def _adf_bandwidth_possible(self) -> str:
        """
        """
        return "300-600MHz"

    def _check_adf_bandwidth(self) -> bool:
        """
        """
        return True

    def _get_adf_tsweep(self, strval: bool = False):
        """
        """
        if strval:
            if self.adf_tsweep:
                return str(self.adf_tsweep)
            else:
                return "None"
        return self.adf_tsweep

    def _set_adf_tsweep(self, newval: str):
        """
        """
        self.adf_tsweep = float(newval)
        if not self.adf_bandwidth is None:
            if not self.min_freq is None:
                self.min_dist = freq_to_dist(
                    self.min_freq, self.adf_bandwidth, self.adf_tsweep
                )
            if not self.max_freq is None:
                self.max_dist = freq_to_dist(
                    self.max_freq, self.adf_bandwidth, self.adf_tsweep
                )

    def _adf_tsweep_possible(self) -> str:
        """
        TODO should correctly report supported values.
        """
        return "1e-3"

    def _check_adf_tsweep(self) -> bool:
        """
        """
        return True

    def _get_adf_tdelay(self, strval: bool = False):
        """
        """
        if strval:
            if self.adf_tdelay:
                return str(self.adf_tdelay)
            else:
                return "None"
        return self.adf_tdelay

    def _set_adf_tdelay(self, newval: str):
        """
        """
        self.adf_tdelay = float(newval)

    def _adf_tdelay_possible(self) -> str:
        """
        TODO should correctly report supported values.
        """
        return "2e-3"

    def _check_adf_tdelay(self) -> bool:
        """
        """
        return True

    def _get_min_freq(self, strval: bool = False):
        """
        """
        if strval:
            return str(self.min_freq)
        return self.min_freq

    def _set_min_freq(self, newval: str):
        """
        """
        self.min_freq = int(float(newval))
        self.min_dist = freq_to_dist(
            self.min_freq, self.adf_bandwidth, self.adf_tsweep
        )

    def _min_freq_possible(self) -> str:
        """
        """
        return "Any non-negative integer less than the max frequency."

    def _check_min_freq(self) -> bool:
        """
        """
        if self.min_freq < self.max_freq and self.min_freq >= 0:
            return True
        return False

    def _get_max_freq(self, strval: bool = False):
        """
        """
        if strval:
            return str(self.max_freq)
        return self.max_freq

    def _set_max_freq(self, newval: str):
        """
        """
        self.max_freq = int(float(newval))
        self.max_dist = freq_to_dist(
            self.max_freq, self.adf_bandwidth, self.adf_tsweep
        )

    def _max_freq_possible(self) -> str:
        """
        """
        return (
            "Any non-negative integer greater than the min frequency "
            "and no greater than the max frequency supported by the "
            "display output."
        )

    def _check_max_freq(self) -> bool:
        """
        """
        display_output_max_f = 1e6
        if self._display_output == Data.RAW:
            display_output_max_f = 20e6
        if (
            self.max_freq > self.min_freq
            and self.max_freq <= display_output_max_f
        ):
            return True
        return False

    def _get_min_dist(self, strval: bool = False):
        """
        """
        if strval:
            return str(self.min_dist)
        return self.min_dist

    def _set_min_dist(self, newval: str):
        """
        """
        self.min_dist = int(newval)
        self.min_freq = dist_to_freq(
            self.min_dist, self.adf_bandwidth, self.adf_tsweep
        )

    def _min_dist_possible(self) -> str:
        """
        """
        return "Any non-negative integer less than the max distance."

    def _check_min_dist(self) -> bool:
        """
        """
        if self.min_dist < self.max_dist and self.min_dist >= 0:
            return True
        return False

    def _get_max_dist(self, strval: bool = False):
        """
        """
        if strval:
            return str(self.max_dist)
        return self.max_dist

    def _set_max_dist(self, newval: str):
        """
        """
        self.max_dist = int(newval)
        self.max_freq = dist_to_freq(
            self.max_dist, self.adf_bandwidth, self.adf_tsweep
        )

    def _max_dist_possible(self) -> str:
        """
        """
        return (
            "Any non-negative integer greater than the min distance "
            "and no greater than the max distance supported by the "
            "display output and ADF configuration."
        )

    def _check_max_dist(self) -> bool:
        """
        """
        display_output_max_f = 1e6
        if self._display_output == Data.RAW:
            display_output_max_f = 20e6
        dist_max = freq_to_dist(
            display_output_max_f, self.adf_bandwidth, self.adf_tsweep
        )

        if self.max_dist > self.min_dist and self.max_dist <= dist_max:
            return True
        return False

    def _get_spectrum_axis(self, strval: bool = False):
        """
        """
        return self.spectrum_axis

    def _set_spectrum_axis(self, newval: str):
        """
        """
        newval_lower = newval.lower()
        if newval_lower == "freq" or newval_lower == "f":
            self.spectrum_axis = "freq"
        elif newval_lower == "dist" or newval_lower == "d":
            self.spectrum_axis = "dist"
        else:
            print(
                "Invalid spectrum axis specified. Setting it to dist. "
                "Please reconfigure it with a permissible entry."
            )
            self.spectrum_axis = "dist"

    def _spectrum_axis_possible(self) -> str:
        """
        """
        return "freq or dist (case-insensitive)"

    def _check_spectrum_axis(self) -> bool:
        """
        """
        return True

    def _get_report_avg(self, strval: bool = False):
        """
        """
        if strval:
            if self.report_avg:
                return "True"
            return "False"
        return self.report_avg

    def _set_report_avg(self, newval: str):
        """
        """
        newval_lower = newval.lower()
        if newval_lower == "true" or newval_lower == "t":
            self.report_avg = True
        elif newval_lower == "false" or newval_lower == "f":
            self.report_avg = False
        else:
            print(
                "Invalid value for report average. Setting it to False. "
                "Please reconfigure it with a permissible entry."
            )
            self.report_avg = False

    def _report_avg_possible(self) -> str:
        """
        """
        return "True or false (case-insensitive)"

    def _check_report_avg(self) -> bool:
        """
        """
        return True

    def _check_parameters(self) -> bool:
        """
        """
        valid = True
        valid &= self._check_fpga_output()
        valid &= self._check_display_output()
        valid &= self._check_log_file()
        valid &= self._check_time()
        valid &= self._check_plot_type()
        valid &= self._check_db_min()
        valid &= self._check_db_max()
        valid &= self._check_plot_dir()
        valid &= self._check_sub_last()
        valid &= self._check_channel()
        valid &= self._check_adf_fstart()
        valid &= self._check_adf_bandwidth()
        valid &= self._check_adf_tsweep()
        valid &= self._check_adf_tdelay()
        valid &= self._check_min_freq()
        valid &= self._check_max_freq()
        valid &= self._check_min_dist()
        valid &= self._check_max_dist()
        valid &= self._check_spectrum_axis()
        valid &= self._check_report_avg()

        return valid

    def _max_param_name_width(self) -> int:
        """
        """
        width = 0
        for param in self.params:
            param_width = len(param.name)
            if param_width > width:
                width = param_width

        return width


class Proc:
    """
    Data processing.
    """

    def __init__(self):
        """
        """
        self._output = None
        self.indata = None
        self.spectrum = None
        self._sub_last = None
        self.last_seq = None
        self.db_min = None
        self.db_max = None

    @property
    def output(self) -> Data:
        """
        """
        return self._output

    @output.setter
    def output(self, newval: Data):
        """
        """
        self._output = newval
        if self._output.value > Data.RAW:
            self._init_fir()
        if self._output.value > Data.DECIMATE:
            self._init_window()

    @property
    def sub_last(self) -> bool:
        """
        """
        return self._sub_last

    @sub_last.setter
    def sub_last(self, newval: bool):
        """
        """
        self._sub_last = newval

    def set_last_seq(self):
        """
        """
        if self._sub_last:
            self.last_seq = np.zeros(data_sweep_len(self.indata))

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
        self.window_coeffs = np.kaiser(data_sweep_len(Data.WINDOW), 6)

    def process_sequence(self, seq: np.array) -> np.array:
        """
        """
        if self.sub_last:
            new_seq = np.subtract(seq, self.last_seq)
            self.last_seq = np.copy(seq)
            seq = new_seq
            if self.indata == Data.FFT:
                seq = np.abs(seq)

        i = self.indata.value
        seq = seq.astype(np.double)
        proc_func = [
            self.perform_fir,
            self.perform_decimate,
            self.perform_window,
            self.perform_fft,
        ]
        while i < self.output.value:
            seq = proc_func[i](seq)
            i += 1

        # normally, we should normalize the FFT FPGA output by
        # dividing by N and then divide our maxval by N. However,
        # these effects cancel and collectively have no net
        # effect. Therefore, we omit both steps.
        if self.indata == Data.FFT:
            seq = seq[0 : spectrum_len(self.indata)]

        nbits = data_nbits(self.indata)
        maxval = 2 ** (nbits - 1)
        # sub_last has a much greater effect on the FFT output than
        # time-series outputs.
        if self.indata == Data.FFT and self.sub_last:
            maxval /= 2 << 5

        if self.output == Data.FFT:
            seq = db_arr(seq, maxval, self.db_min, self.db_max)
        elif self.spectrum:
            seq = self.perform_fft(seq)
            seq = db_arr(seq, maxval, self.db_min, self.db_max)

        return seq

    def perform_fir(self, seq: np.array) -> np.array:
        """
        """
        fir = np.convolve(seq, self.taps)
        return fir[: len(seq)]

    def perform_decimate(self, seq: np.array) -> np.array:
        """
        """
        dec_arr = [seq[i] for i in range(len(seq)) if i % DECIMATE == 0]
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
        fft /= len(fft)
        return np.abs(fft)


class Shell:
    """
    """

    def __init__(self):
        """
        """
        self.plot = Plot()
        self.proc = Proc()
        self.configuration = Configuration(self.plot, self.proc)
        self.help()
        self.prompt()

    def prompt(self):
        """
        """
        write("fmcw > ", newline=False)
        self.read_input()

    def set_prompt(self):
        """
        """
        write("set > ", newline=False)
        uinput = self._readline()
        int_input = int(uinput)
        param = self.configuration.param_for_number(int_input)
        param_str = (
            ("Parameter       : {}\n".format(param.name))
            + ("Current Value   : {}\n".format(param.getter(strval=True)))
            + ("Possible Values : {}\n\n".format(param.possible()))
            + "**Note that when setting selection options (e.g. plot type),\n"
            + "it is only necessary to type the first characters that fully\n"
            + "differentiate the selection from all other choices.\n"
        )
        write(param_str)
        write("new value > ", newline=False)
        uinput = self._readline()
        param.setter(uinput)
        write("New value set.\n")

    def read_input(self):
        """
        """
        uinput = self._readline()
        if uinput == "exit":
            return
        elif uinput == "help":
            self.help()
        elif uinput == "conf":
            write(self.configuration.display(), newline=True)
        elif uinput == "set":
            write(self.configuration.display_number_menu(), newline=True)
            self.set_prompt()
        elif uinput == "run":
            if not self.configuration._check_parameters():
                raise RuntimeError("Invalid configuration. Exiting.")
            if self.configuration.spectrum_axis == "freq":
                self.plot.min_axis_val = self.configuration.min_freq
                self.plot.max_axis_val = self.configuration.max_freq
            else:
                self.plot.min_axis_val = self.configuration.min_dist
                self.plot.max_axis_val = self.configuration.max_dist
            min_bin = int(
                np.round(
                    spectrum_len(self.configuration._display_output)
                    / nyquist_freq(self.configuration._display_output)
                    * self.configuration.min_freq
                )
            )
            max_bin = int(
                np.round(
                    spectrum_len(self.configuration._display_output)
                    / nyquist_freq(self.configuration._display_output)
                    * self.configuration.max_freq
                )
            )
            self.plot.min_bin = min_bin
            self.plot.max_bin = max_bin
            self.plot.initialize_plot()
            self.proc.set_last_seq()
            self.run()
        else:
            write("Unrecognized input. Try again.")
            self.help()

        self.prompt()

    def help(self):
        """
        """
        help_str = (
            "Available commands:\n"
            + HORIZONTAL_LINES
            + "conf : Display current configuration.\n"
            + "exit : Exit.\n"
            + "help : This display.\n"
            + (
                "run  : Instantiate the current configuration, \n"
                "       begin data acquisition, and display output.\n"
            )
            + (
                "set  : Change the value of a configuration \n"
                "       variable.\n"
            )
            # + "stop : Terminate the current data acquisition early.\n"
        )
        write(help_str)

    def run(self) -> None:
        """
        """
        nseq = 0
        current_time = clock_gettime(CLOCK_MONOTONIC)
        start_time = current_time
        end_time = start_time + self.configuration.time
        sweep_len = data_sweep_len(self.configuration._fpga_output)
        sample_bits = data_nbits(self.configuration._fpga_output)
        if self.configuration.logp():
            log_file = self.configuration.log_file.as_posix()
        else:
            log_file = None

        if self.configuration.report_avg:
            avg = []

        with Device() as radar:
            radar.adf.fstart = self.configuration.adf_fstart
            radar.adf.tsweep = self.configuration.adf_tsweep
            radar.adf.tdelay = self.configuration.adf_tdelay
            radar.adf.bandwidth = self.configuration.adf_bandwidth
            radar.set_chan(self.configuration.channel)
            radar.set_output(
                data_to_fpga_output(self.configuration._fpga_output)
            )
            radar.set_adf_regs()

            radar.start_acquisition(
                log_file,
                sample_bits,
                sweep_len,
                self.configuration._fpga_output == Data.FFT,
            )
            while current_time < end_time:
                sweep = radar.read_sweep(sweep_len)
                if sweep is not None:
                    proc_sweep = self.proc.process_sequence(sweep)
                    clipped_sweep = proc_sweep[
                        self.plot.min_bin : self.plot.max_bin
                    ]
                    self.plot.add_sweep(clipped_sweep)
                    if self.configuration.report_avg:
                        avg.append(np.average(clipped_sweep))
                    nseq += 1
                current_time = clock_gettime(CLOCK_MONOTONIC)

        if self.configuration.report_avg:
            write(avg_value(np.average(avg)))
        write(plot_rate(nseq, current_time - start_time))
        tbytes = sweep_total_bytes(self.configuration._fpga_output)
        write(
            usb_bandwidth(nseq * tbytes, current_time - start_time),
            newline=True,
        )

    def _readline(self) -> str:
        """
        """
        return sys.stdin.readline()[:-1]


if __name__ == "__main__":
    shell = Shell()
