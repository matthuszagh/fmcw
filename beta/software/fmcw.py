#!/usr/bin/env python
from __future__ import annotations
from time import clock_gettime, CLOCK_MONOTONIC
import sys
from enum import IntEnum, auto
from typing import Union, Optional, Callable, List
from pathlib import Path
from shutil import rmtree
from multiprocessing import Process, Pipe
from multiprocessing.connection import Connection
from queue import Queue
import pylibftdi as ftdi
import numpy as np
from pyqtgraph.Qt import QtGui
import pyqtgraph as pg
from scipy import signal

BITMODE_SYNCFF = 0x40
CHUNKSIZE = 0x10000
SIO_RTS_CTS_HS = 0x1 << 8
START_FLAG = 0xFF
STOP_FLAG = 0x8F
RAW_LEN = 20480
FS = 40e6
PASS_DB = 0.5
STOP_DB = -40
NUMTAPS = 120
BANDS = [0, 0.5e6, 1.0e6, 20e6]
BAND_GAIN = [1, 0]
DECIMATE = 20
DECIMATED_LEN = RAW_LEN // DECIMATE
FFT_LEN = DECIMATED_LEN // 2 + 1
BYTE_BITS = 8
ADC_BITS = 12
HIST_RANGE = 2000
# TODO might need to be set programmatically
DECIMATE_BITS = 14
WINDOW_BITS = 14
FFT_BITS = 25


HORIZONTAL_LINES = "----------\n"


class Data(IntEnum):
    RAW = auto()
    FIR = auto()
    DECIMATE = auto()
    WINDOW = auto()
    FFT = auto()


def data_from_str(strval: str) -> Data:
    """
    """
    strval = strval.lower()
    if strval == "raw":
        return Data.RAW
    elif strval == "fir":
        return Data.FIR
    elif strval == "decimate":
        return Data.DECIMATE
    elif strval == "window":
        return Data.WINDOW
    elif strval == "fft":
        return Data.FFT

    raise RuntimeError("Invalid Data string.")


def data_sweep_len(data: Data) -> int:
    """
    """
    if data == Data.RAW or data == Data.FIR:
        return RAW_LEN
    if data == Data.DECIMATE or data == Data.WINDOW:
        return DECIMATED_LEN
    if data == Data.FFT:
        return FFT_LEN

    raise ValueError("Invalid Data value.")


def data_nbits(data: Data) -> int:
    """
    """
    if data == Data.RAW:
        return ADC_BITS
    if data == Data.DECIMATE:
        return DECIMATE_BITS
    if data == Data.WINDOW:
        return WINDOW_BITS
    if data == Data.FFT:
        return FFT_BITS

    raise ValueError("Invalid Data value.")


def num_flags(num_bits: int) -> int:
    """
    The number of start and stop flag bytes for a payload with a given
    number of bits.  Each sample is MSB-padded with 0s until it is
    byte-aligned.  The MSB of the sample + padding is guaranteed to be
    zero.  That is, at least 1 0-bit is padded to each sample.  This
    allows us to distinguish a start or stop flag from a sample.  The
    flag length is therefore equal to the number of bytes of the
    sample + padding.
    """
    full_bytes = num_bits // BYTE_BITS
    return full_bytes + 1


def write(txt: str, newline: bool = True):
    """
    """
    sys.stdout.write(txt)
    if newline:
        sys.stdout.write("\n")
    sys.stdout.flush()


def log(fpath: Path, pipe: Connection):
    """
    """
    f = fpath.open("wb")
    read_data = pipe.recv()
    while read_data:
        f.write(read_data)
        read_data = pipe.recv()

    f.close()
    pipe.close()


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


def db_arr(indata, maxval):
    return 20 * np.log10(indata / maxval)


class Radar:
    """
    """

    def __init__(self):
        """
        """
        self.device = ftdi.Device(mode="b", interface_select=ftdi.INTERFACE_A)
        self.device.open()
        self.device.ftdi_fn.ftdi_set_bitmode(0xFF, BITMODE_SYNCFF)
        self.device.ftdi_fn.ftdi_setflowctrl(SIO_RTS_CTS_HS)
        self.device.ftdi_fn.ftdi_set_latency_timer(2)
        self.device.ftdi_fn.ftdi_read_data_set_chunksize(CHUNKSIZE)
        self.device.ftdi_fn.ftdi_write_data_set_chunksize(CHUNKSIZE)
        self.device.flush()

        self._data_queue = Queue()
        self._queue_size = 0
        self._sweep = None
        self._sweep_idx = 0
        self._start_flag_count = 0
        self._stop_flag_count = 0

        # set later
        self._fpga_output = None

    @property
    def fpga_output(self) -> Data:
        """
        """
        return self._fpga_output

    @fpga_output.setter
    def fpga_output(self, newval: Data):
        """
        """
        self._fpga_output = newval
        self._sweep = np.zeros(data_sweep_len(newval), dtype=int)

    def read(self):
        """
        Read a chunk of data from the radar.
        """
        data = self.device.read(CHUNKSIZE)
        data_bytes = np.frombuffer(data, dtype=np.uint8)
        data_len = len(data)
        if data_len > 0:
            for val in data_bytes:
                self._data_queue.put(val)
            self._queue_size += data_len

        return data

    def read_sweep(self) -> Optional[np.array]:
        """
        Read the next full sweep of data.  This does not actually
        perform a read from the device.  Instead, it returns data
        already acquired by read().  Therefore, you must call read
        prior to calling this.

        :returns: The next sweep of data or None if the acquired data
                  does not contain a full sweep.
        """
        sweep_len = data_sweep_len(self.fpga_output)
        sample_bits = data_nbits(self.fpga_output)
        nflags = num_flags(sample_bits)
        if sweep_len * sample_bits + 2 * nflags > self._queue_size * BYTE_BITS:
            return None

        if not self._stop_flag_count == 0:
            if self._read_stop_sequence(nflags):
                sweep = np.copy(self._sweep)
                self._zero_sweep()
                return sweep

        if not self._sweep_idx == 0:
            if self._read_sample_sequence(sample_bits, sweep_len):
                if self._read_stop_sequence(nflags):
                    sweep = np.copy(self._sweep)
                    self._zero_sweep()
                    return sweep

        if self._read_start_sequence(nflags):
            if self._read_sample_sequence(sample_bits, sweep_len):
                if self._read_stop_sequence(nflags):
                    sweep = np.copy(self._sweep)
                    self._zero_sweep()
                    return sweep

        return None

    def _read_start_sequence(self, nflags: int) -> bool:
        """
        """
        while self._start_flag_count < nflags:
            if self._queue_size == 0:
                return False
            qval = self._data_queue.get()
            self._queue_size -= 1
            if qval == START_FLAG:
                self._start_flag_count += 1
            else:
                self._start_flag_count = 0

        # A read chunk can end on a full start sequence.
        if not self._queue_size == 0:
            self._start_flag_count = 0
        return True

    def _read_stop_sequence(self, nflags: int) -> bool:
        """
        :returns: True if full stop sequence read.  Otherwise returns
                  false.
        """
        # for i in range(self._sweep_idx):
        #     print("{:6}: {}".format(i, self._sweep[i]))
        while self._stop_flag_count < nflags:
            if self._queue_size == 0:
                return False
            self._sweep_idx = 0
            qval = self._data_queue.get()
            self._queue_size -= 1
            if qval == STOP_FLAG:
                self._stop_flag_count += 1
            else:
                # We did not read a full stop sequence. Drop all data
                # and start again with the next sweep.
                self._zero_sweep()
                self._start_flag_count = 0
                self._stop_flag_count = 0
                return False

        self._zero_sweep()
        self._start_flag_count = 0
        self._stop_flag_count = 0
        return True

    def _read_sample_sequence(self, sample_bits: int, sweep_len: int) -> bool:
        """
        :returns: True if full sequence read. False otherwise.
        """
        sample_bytes = num_flags(sample_bits)
        sample_array = []
        while self._queue_size > sample_bytes and self._sweep_idx < sweep_len:
            for elem in range(sample_bytes):
                sample_array.append(self._data_queue.get())
            val = number_from_array(sample_array, sample_bits)
            self._sweep[self._sweep_idx] = val
            self._queue_size -= sample_bytes
            self._sweep_idx += 1
            sample_array = []

        if self._sweep_idx == sweep_len:
            return True
        # We've read a partial sweep. Maintain sweep_idx to continue
        # with the next read chunk.
        return False

    def _zero_sweep(self) -> None:
        """
        """
        self._sweep_idx = 0
        # if not self._sweep_idx == 0:
        #     self._sweep = np.zeros(data_sweep_len(self._fpga_output))
        #     self._sweep_idx = 0

    def program(self):
        """
        """
        if not self.fpga_output == Data.RAW:
            raise RuntimeError("Only raw FPGA output currently supported.")


class PlotType(IntEnum):
    TIME = auto()
    SPECTRUM = auto()
    HIST = auto()


def plot_type_from_str(strval: str) -> PlotType:
    """
    """
    strval = strval.lower()
    if strval == "time":
        return PlotType.TIME
    elif strval == "spectrum":
        return PlotType.SPECTRUM
    elif strval == "hist":
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
        self.db_min = None
        self.db_max = None
        self.plot_path = None

    def set_type(self, ptype: PlotType, output: Data) -> None:
        """
        Set the plot and output type.
        """
        self._ptype = ptype
        self._output = output
        self._set_type_and_output()

    @property
    def ptype(self) -> PlotType:
        """
        """
        return self._ptype

    @ptype.setter
    def ptype(self, newval: Data):
        """
        """
        if self._output is None:
            raise RuntimeError("Must set output type before plot type.")

        if self._ptype is not None:
            self._close_plot()

        self._ptype = newval

        if self._ptype == PlotType.TIME:
            self._data = np.zeros(data_sweep_len(self._output))
            self._initialize_time_plot()
        elif self._ptype == PlotType.SPECTRUM:
            self._data = np.zeros(data_sweep_len(self._output) // 2 + 1)
            self._initialize_spectrum_plot()
        elif self._ptype == PlotType.HIST:
            self._data = np.zeros((HIST_RANGE, data_sweep_len(self._output)))
            self._initialize_hist_plot()
        else:
            raise ValueError("Invalid plot type.")

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

    def _initialize_time_plot(self) -> None:
        """
        """
        self._win = pg.PlotWidget()
        self._win.setWindowTitle("Time Plot (" + self._output.name + ")")
        self._win.setXRange(0, self._data.shape[0])
        self._win.show()

    def _initialize_spectrum_plot(self) -> None:
        """
        """
        self._win = pg.PlotWidget()
        self._win.setWindowTitle("Spectrum Plot (" + self._output.name + ")")
        self._win.setXRange(0, self._data.shape[0] // 2 + 1)
        self._win.show()

    def _initialize_hist_plot(self) -> None:
        """
        """
        self._fname = 0
        self._xval = 0
        self._win = QtGui.QMainWindow()
        self._imv = pg.ImageView(view=pg.PlotItem())
        self._img_view = self._imv.getView()
        self._img_view.invertY(False)
        self._img_view.setLimits(yMin=0, yMax=self._data.shape[1])
        self._img_view.getAxis("left").setScale(0.5)
        self._win.setCentralWidget(self._imv)
        self._win.show()
        self._win.setWindowTitle(
            "Range-Time Histogram (" + self._output.name + ")"
        )
        self._imv.setPredefinedGradient("flame")

    def _close_plot(self) -> None:
        """
        """
        self._win.close()

    def _add_time_sweep(self, sweep: np.array) -> None:
        """
        """
        # makes the update much faster
        ranges = subdivide_range(self._data.shape[0], 100)
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

        self._data = np.zeros(self._data.shape)

    def _add_spectrum_sweep(self, sweep: np.array) -> None:
        """
        """
        self._win.plot(
            np.linspace(0, self._data.shape[0] - 1, self._data.shape[0]),
            sweep,
            clear=True,
        )
        self._app.processEvents()

    def _add_hist_sweep(self, sweep: np.array) -> None:
        """
        """
        self._data[self._xval] = sweep
        xrg = self._data.shape[0]
        self._imv.setImage(self._data, xvals=[i for i in range(xrg)])

        if self.db_min is None:
            db_min = -120
        else:
            db_min = self.db_min
        if self.db_max is None:
            db_max = 0
        else:
            db_max = self.db_max
        self._imv.setLevels(db_min, db_max)
        self._app.processEvents()

        self._xval += 1
        if self._xval == xrg:
            if self._save_plotsp():
                self._save_hist()
                self._fname += 1
            self._data = np.zeros(np.shape(self._data))
            self._xval = 0

    def _save_hist(self) -> None:
        """
        """
        self._imv.export(self.plot_path.as_posix() + str(self._fname) + ".png")

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

    def __init__(self, radar: Radar, plot: Plot, proc: Proc):
        """
        """
        self.radar = radar
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
                init="30",
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
                init="-80",
            ),
            Parameter(
                name="dB max",
                number=self._get_inc_ctr(),
                getter=self._get_db_max,
                setter=self._set_db_max,
                possible=self._db_max_possible,
                init="0",
            ),
            Parameter(
                name="plot save dir",
                number=self._get_inc_ctr(),
                getter=self._get_plot_dir,
                setter=self._set_plot_dir,
                possible=self._plot_dir_possible,
                init="",
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

        self.radar.fpga_output = self._fpga_output
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
        if self.fpga_output > self.display_output:
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
            "Integer representing time (defaults to seconds). \n"
            "s, m, h, d can be appended for seconds, minutes, hours \n"
            "or days if desired. Therefore, using `s` will have no effect."
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
        if self.ptype == PlotType.SPECTRUM:
            self.proc.spectrum = True

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
            self.db_min = None
        else:
            self.db_min = float(newval)
        self.plot.db_min = self.db_min

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
            self.db_max = None
        self.db_max = float(newval)
        self.plot.db_max = self.db_max

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
        if self._sub_last:
            self.last_seq = np.zeros(data_sweep_len(self.output))

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

        i = self.indata.value
        proc_func = [
            self.perform_fir,
            self.perform_decimate,
            self.perform_window,
            self.perform_fft,
        ]
        while i < self.output.value - 1:
            seq = proc_func[i](seq)
            i += 1

        if self.output == Data.FFT:
            # TODO what should maxval be?
            seq = db_arr(seq, len(seq))

        if self.spectrum:
            seq = np.abs(np.fft.rfft(seq))
            # TODO what should maxval be?
            seq = db_arr(seq, len(seq))

        return seq

    def perform_fir(self, seq: np.array) -> np.array:
        """
        """
        fir = np.convolve(seq, self.taps, mode="same")
        return fir

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
        return np.abs(fft)


class Shell:
    """
    """

    def __init__(self):
        """
        """
        self.radar = Radar()
        self.plot = Plot()
        self.proc = Proc()
        self.configuration = Configuration(self.radar, self.plot, self.proc)
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
            + ("Possible Values : {}\n".format(param.possible()))
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
            self.radar.program()
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
        logging = False
        if self.configuration.logp():
            logging = True
            log_pipe, child_conn = Pipe()
            log_proc = Process(
                target=log, args=(self.configuration.log_file, child_conn)
            )
            log_proc.start()

        nseq = 0
        current_time = clock_gettime(CLOCK_MONOTONIC)
        start_time = current_time
        end_time = start_time + self.configuration.time
        f = open("log.txt", "w")
        while current_time < end_time:
            full_data = self.radar.read()
            sweep = self.radar.read_sweep()
            while not sweep is None:
                proc_sweep = self.proc.process_sequence(sweep)
                self.plot.add_sweep(proc_sweep)
                sweep = self.radar.read_sweep()
            if logging:
                log_pipe.send(full_data)
            nseq += 1
            current_time = clock_gettime(CLOCK_MONOTONIC)

        f.close()

        if logging:
            log_pipe.send(False)
            log_proc.join()

        write(
            self._bandwidth(nseq * CHUNKSIZE, current_time - start_time),
            newline=True,
        )

    def _readline(self) -> str:
        """
        """
        return sys.stdin.readline()[:-1]

    def _bandwidth(self, nbytes: int, nsec: float) -> str:
        """
        """
        bwidth = nbytes / nsec
        for unit in ["B", "kB", "MB", "GB"]:
            if bwidth < 10 ** 3:
                return "Bandwidth: {} {}/s\n".format(round(bwidth, 3), unit)
            bwidth /= 10 ** 3

        return "Bandwidth: {} GB/s\n".format(round(bwidth, 3))


if __name__ == "__main__":
    shell = Shell()
