# cython: language_level=3
# cython: c_string_type=str, c_string_encoding=ascii

# cimport numpy as np
import numpy as np
from typing import List
from cdevice cimport (
    fmcw_open as c_fmcw_open,
    fmcw_close as c_fmcw_close,
    fmcw_start_acquisition as c_fmcw_start_acquisition,
    fmcw_read_sweep as c_fmcw_read_sweep,
    fmcw_write as c_fmcw_write
)

def param_mask(length: int) -> int:
    """
    Parameter bit mask.
    """
    return 2**length-1

def param_lsb(msb: int, length: int) -> int:
    """
    Parameter LSB.
    """
    return msb - length + 1


class ADF4158:
    """
    """
    def __init__(self):
        self._params = {
            # ====================== REGISTER 0 ======================

            # ramp on is not exposed since its value is set by logic
            # on the FPGA and would be ignored if set here.

            # Sets which internal data is readback on the muxout pin. The
            # default sets this to digital lock detect, which indicates
            # whether the PLL frequency is locked. If using READBACK_MUXOUT,
            # this must be set to 4'b1111. For other values, see the
            # datasheet.
            "muxout": {"num": 0, "msb": 30, "len": 4, "val": 0xF},
            # Frequency multiplier for VCO output frequency. See ``f_pfd``.
            "int": {"num": 0, "msb": 26, "len": 12, "val": None},
            # Fractional value used in determining the VCO output
            # frequency. 12 most significant bits.
            "frac_msb": {"num": 0, "msb": 14, "len": 12, "val": None},

            # ====================== REGISTER 1 ======================

            # Fractional value used in determining the VCO output
            # frequency. 13 least significant bits.
            "frac_lsb": {"num": 1, "msb": 27, "len": 13, "val": None},

            # ====================== REGISTER 2 ======================

            # Enable cycle slip reduction, which improves frequency lock
            # times. To be used, the PFD reference frequency must have a 50%
            # duty cycle, CP_CURRENT must be 0, and PD must be 1.
            "csr_en": {"num": 2, "msb": 28, "len": 1, "val": 1},
            # Charge pump current setting.
            "cp_current": {"num": 2, "msb": 27, "len": 4, "val": 0},
            # Prescale. Must be set to 1 for freq > 3GHz.
            "prescaler": {"num": 2, "msb": 22, "len": 1, "val": 1},
            # The R-Divider. Setting this to 1 can be used with cycle slip
            # reduction. See ``f_pfd``.
            "rdiv2": {"num": 2, "msb": 21, "len": 1, "val": None},
            # Reference doubler. Can only be used when the input reference
            # frequency is no greater than 30MHz. See ``f_pfd``.
            "doubler": {"num": 2, "msb": 20, "len": 1, "val": None},
            # The R-Counter divides REF_IN (clk input) to produce the
            # reference clock for the PFD. See ``f_pfd``.
            "r_counter": {"num": 2, "msb": 19, "len": 5, "val": None},
            # Clock 1 divider. Determines the duration of a ramp step in ramp
            # mode. See ``timer``.
            "clk1_div": {"num": 2, "msb": 14, "len": 12, "val": None},

            # ====================== REGISTER 3 ======================

            # N SEL prevents INT and FRAC from loading at different times and
            # causing a frequency overshoot. Set to 1 to use.
            "n_sel": {"num": 3, "msb": 15, "len": 1, "val": 1},
            # Resets the Sigma-Delta modulator on each write to R0. Set to 1
            # to use. This generally does not need to be set.
            "sd_reset": {"num": 3, "msb": 14, "len": 1, "val": 0},
            # Sets the ramp mode. See datasheet for available modes. The
            # default (2'b00) sets the ramp mode to continous sawtooth.
            "ramp_mode": {"num": 3, "msb": 11, "len": 2, "val": 0},
            # Set to 1 to enable PSK modulation.
            "psk_en": {"num": 3, "msb": 9, "len": 1, "val": 0},
            # Set to 1 to enable FSK modulation.
            "fsk_en": {"num": 3, "msb": 8, "len": 1, "val": 0},
            # Lock detect precision determines the number of consecutive PFD
            # cycles that must pass before the digital lock detect is
            # set. Setting this to 0 uses lower precision (24 cycles of
            # 15ns). Setting to 1 uses higher precision (40 cycles of 15ns).
            "ldp": {"num": 3, "msb": 7, "len": 1, "val": 0},
            # Phase detector polarity. Set this to 1 when the VCO output
            # changes positively with positive changes in input. Set this to 0
            # if changes to the VCO's output and input are inversely related.
            "pd": {"num": 3, "msb": 6, "len": 1, "val": 1},
            # Software power-down. This disables the frequency output but
            # registers maintain state and remain capable of loading new
            # values. Setting this bit to 1 performs a power down.
            "power_down": {"num": 3, "msb": 5, "len": 1, "val": 0},
            # Places the charge pump in 3-state mode when set to 1. Set this
            # to 0 for normal operation.
            "cp3": {"num": 3, "msb": 4, "len": 1, "val": 0},
            # Set to 1 to reset the RF synthesizer counters. This should be
            # set to 0 when in normal operation.
            "counter_reset": {"num": 3, "msb": 3, "len": 1, "val": 0},

            # ====================== REGISTER 4 ======================

            # Load enable select. Setting this to 1 enables it. See datasheet
            # for information.
            "le_sel": {"num": 4, "msb": 31, "len": 1, "val": 0},
            # Sets the Delta-Sigma modulator mode. Set to 5'b0_0000 for normal
            # operation. See the datasheet for alternative operating states.
            "delta_sigma": {"num": 4, "msb": 30, "len": 5, "val": 0},
            # Setting the negative bleed current to 2'b11 enables constant
            # negative bleed current which ensures the charge pump operates
            # outside its dead zone. Set this to 2'b00 to disable it. If this
            # is enabled, READBACK_MUXOUT must be disabled.
            "bleed_current": {"num": 4, "msb": 24, "len": 2, "val": 0},
            # Enables reading back the synthesizer's frequency at the moment
            # of interrupt. Set this to 2'b00 to disable, or 2'b10 to enable.
            "readback_muxout": {"num": 4, "msb": 22, "len": 2, "val": 3},
            # Setting clock divider mode to 2'b11 enables ramping. If instead
            # you want the fast-lock mode, set this to 2'b01.
            "clk_div_mode": {"num": 4, "msb": 20, "len": 2, "val": 3},
            # Clock 2 divider. Determines the duration of a ramp step in ramp
            # mode. See ``timer``.
            "clk2_div": {"num": 4, "msb": 18, "len": 12, "val": None},

            # ====================== REGISTER 5 ======================

            # Set this to 0 to use the clock divider clock for clocking a
            # ramp. Set this to 1 to use the TX data clock instea.
            "tx_ramp_clk": {"num": 5, "msb": 29, "len": 1, "val": 0},
            # 0 disables a parabolic ramp. 1 enables it.
            "par_ramp": {"num": 5, "msb": 28, "len": 1, "val": 0},
            # Determines the type of interrupt used. This can be used with the
            # READBACK_MUXOUT function to read back INT and FRAC at the moment
            # of interrupt. The rising edge of tx_data triggers the interrupt,
            # and the interrupt finishes when the readback is finished. Set
            # this to 2'b00 to disable interrupts. 2'b01 continues the sweep
            # at its last value prior to interrupt. 2'b11 freezes the sweep at
            # that value.
            "interrupt": {"num": 5, "msb": 27, "len": 2, "val": 0},
            # Setting this to 1 enables the FSK ramp. 0 disables it.
            "fsk_ramp_en": {"num": 5, "msb": 25, "len": 1, "val": 0},
            # Setting this to 1 enables the second ramp. 0 disables it.
            "ramp2_en": {"num": 5, "msb": 24, "len": 1, "val": 0},
            # dev sel is not exposed since its value is set by logic
            # on the FPGA and would be ignored if set here.

            # The deviation offset sets the frequency ramp step. See ``f_dev``
            # for details.
            "dev_offset": {"num": 5, "msb": 22, "len": 4, "val": None},
            # Determines the frequency ramp step. See ``f_dev`` for details.
            "dev": {"num": 5, "msb": 18, "len": 16, "val": None},

            # ====================== REGISTER 6 ======================

            # Sets the number of steps in a ramp. Each step has frequency
            # increment f_DEV (``f_dev``) and time step timer (``timer``).
            "ramp_steps": {"num": 6, "msb": 22, "len": 20, "val": None},

            # ====================== REGISTER 7 ======================

            # Setting this to 1 enables the ramp delay fast lock function.
            "ramp_del_fl": {"num": 7, "msb": 18, "len": 1, "val": None},
            # Setting this to 1 enables a delay between ramp bursts. Note that
            # this does not disable frequency output (use PWR_DWN_INIT for
            # that), it simply holds the frequency output at its RF_OUT value.
            "ramp_del": {"num": 7, "msb": 17, "len": 1, "val": None},
            # Setting this to 0 selects the f_PFD clock as the delay
            # clock. Setting this 1 uses f_PFD / CLK1_DIV as delay clock
            # frequency.
            "del_clk_sel": {"num": 7, "msb": 16, "len": 1, "val": None},
            # 1 enables a delayed start.
            "del_start_en": {"num": 7, "msb": 15, "len": 1, "val": None},
            # Sets the number of steps in a delay.
            "del_steps": {"num": 7, "msb": 14, "len": 12, "val": None},
        }
        self._clk_freq = 40e6
        self.f_pfd = 20e6

    def get_param(self, name: str) -> int:
        """
        """
        if not name in self._params:
            raise ValueError("Invalid ADF4158 parameter.")
        return self._params[name]["val"]

    def set_param(self, name: str, newval: int) -> None:
        """
        """
        if not name in self._params:
            raise ValueError("Invalid ADF4158 parameter.")
        max_param = self._max_param(name)
        if newval < 0:
            raise ValueError("ADF4158 parameter {} must be greater than or equal to 0".format(name))
        if newval > max_param:
            raise ValueError("ADF4158 parameter {} max value is {}".format(name, max_param))

        self._params[name]["val"] = newval

    def _max_param(self, name: str) -> int:
        """
        """
        length = self._params[name]["len"]
        return int(2 ** length - 1)

    @property
    def f_pfd(self):
        """
        Phase frequency detector reference frequency.

        f_pfd = 40e6 x [(1 + DOUBLER) / (R_COUNTER x (1 + RDIV2))]
        """
        doubler = self.get_param("doubler")
        r_counter = self.get_param("r_counter")
        rdiv2 = self.get_param("rdiv2")
        return self._clk_freq * ((1 + doubler) / (r_counter * (1 + rdiv2)))

    @f_pfd.setter
    def f_pfd(self, newval: int):
        """
        """
        if not np.isclose(newval, 20e6):
            raise ValueError(
                "Phase frequency detector reference frequency must "
                "be set to 20MHz."
            )
        self.set_param("doubler", 0)
        self.set_param("r_counter", 1)
        self.set_param("rdiv2", 1)

    @property
    def fstart(self):
        """
        Initial ramp frequency.
        """
        int_ = self.get_param("int")
        frac = self.get_param("frac_msb") << 13 + self.get_param("frac_lsb")
        return self.f_pfd * (int_ + (frac / 2**25))

    @fstart.setter
    def fstart(self, newval: float):
        """
        """
        f_pfd = self.f_pfd
        base = int(newval // f_pfd)
        rem = newval % f_pfd
        self.set_param("int", base)
        frac = int(rem / f_pfd * 2**25)
        self.set_param("frac_lsb", frac & 0x1FFF)
        self.set_param("frac_msb", (frac & 0x1FFE000) >> 13)

    @property
    def timer(self) -> int:
        """
        Time between each frequency step in a ramp.
        """
        clk1_div = self.get_param("clk1_div")
        clk2_div = self.get_param("clk2_div")
        f_pfd = self.f_pfd
        return clk1_div * clk2_div * (1/f_pfd)

    @timer.setter
    def timer(self, newval: float) -> None:
        """
        """
        f_pfd = self.f_pfd
        max_clk1 = self._max_param("clk1_div") / f_pfd
        if newval <= max_clk1:
            self.set_param("clk1_div", int(newval * f_pfd))
        else:
            self.set_param("clk1_div", max_clk1)
            rem = newval - max_clk1
            max_clk2 = self._max_param("clk2_div") / f_pfd
            if rem > max_clk2:
                raise ValueError("Timer value {} is too long.".format(newval))
            self.set_param("clk2_div", int(rem * f_pfd))

    @property
    def f_dev(self) -> int:
        """
        Frequency increment in each ramp step.
        """
        dev = self.get_param("dev")
        dev_offset = self.get_param("dev_offset")
        f_pfd = self.f_pfd
        return f_pfd / 2**25 * dev * 2**dev_offset

    @f_dev.setter
    def f_dev(self, newval: int) -> None:
        """
        """
        dev_offset = 4
        self.set_param("dev_offset", dev_offset)
        factor = self.f_pfd / 2**25
        max_dev = self._max_param("dev")
        if newval > max_dev * 2**dev_offset * factor:
            raise ValueError("f_dev is too large.")
        rem = newval / factor / 2**dev_offset
        self.set_param("dev", int(round(rem, 0)))

    @property
    def tsweep(self) -> float:
        """
        """
        return self.timer * self.get_param("ramp_steps")

    @tsweep.setter
    def tsweep(self, newval: float) -> None:
        """
        """
        self.timer = 0.5e-6
        max_steps = self._max_param("ramp_steps")
        if newval > self.timer * max_steps:
            raise ValueError("Sweep length is too long.")
        self.set_param("ramp_steps", int(round(newval / self.timer, 0)))

    @property
    def bandwidth(self) -> float:
        """
        """
        return self.f_dev * self.get_param("ramp_steps")

    @bandwidth.setter
    def bandwidth(self, newval: int) -> None:
        """
        """
        self.f_dev = newval / self.get_param("ramp_steps")

    @property
    def tdelay(self) -> float:
        """
        Delay between successive ramps.
        """
        return self.timer * self.get_param("del_steps")

    @tdelay.setter
    def tdelay(self, newval: float) -> None:
        """
        """
        timer = self.timer
        max_del_steps = self._max_param("del_steps")
        if newval > timer * max_del_steps:
            raise ValueError("Delay period too long.")
        self.set_param("del_steps", int(round(newval / timer, 0)))

    def registers(self) -> List[int]:
        """
        """
        regs = [0 for _ in range(8)]
        for k, v in self._params.items():
            if v["val"] is None:
                raise RuntimeError("{} value not set.".format(k))
            mask = param_mask(v["len"])
            lsb = param_lsb(v["msb"], v["len"])
            regs[v["num"]] |= (mask & v["val"]) << lsb

        # for i, reg in enumerate(regs):
        #     reg |= i

        return regs


class Device:
    """
    Interface to physical radar.
    """

    def __init__(self):
        """
        """
        self._open()
        self.adf = ADF4158()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self._close()

    def _open(self):
        return c_fmcw_open()

    def _close(self):
        self._send_stop()
        c_fmcw_close()

    def start_acquisition(self, log_path: str, sample_bits: int, sweep_len: int):
        if log_path is None:
            return c_fmcw_start_acquisition(NULL, sample_bits, sweep_len)
        ret = c_fmcw_start_acquisition(log_path, sample_bits, sweep_len)
        self._send_start()
        return ret

    def read_sweep(self, sweep_len: int):
        arr = np.empty(sweep_len, dtype=np.int32)
        # TODO necessary?
        if not arr.flags["C_CONTIGUOUS"]:
            arr = np.ascontiguousarray(arr)
        cdef int[::1] arr_memview = arr
        ret = c_fmcw_read_sweep(&arr_memview[0])
        if ret:
            return arr
        return None

    def set_chan(self, chan: str):
        """
        """
        chan = chan.lower()
        if chan not in ["a", "b"]:
            raise ValueError("Channel must be set to A or B.")
        if chan == "a":
            c_fmcw_write(1, 1)
            c_fmcw_write(1, 1)
            c_fmcw_write(2, 1)
            c_fmcw_write(0, 1)
        else:
            c_fmcw_write(1, 1)
            c_fmcw_write(0, 1)
            c_fmcw_write(2, 1)
            c_fmcw_write(1, 1)

    def set_adf_regs(self):
        """
        """
        adf_regs = self.adf.registers()
        for i, reg in enumerate(adf_regs):
            c_fmcw_write(i | 0x80, 1)
            c_fmcw_write(reg, 4)

    def set_output(self, output: str):
        """
        """
        output = output.lower()
        if output not in ["raw", "fir", "window", "fft"]:
            raise ValueError("Output must be RAW, FIR, WINDOW, or FFT.")
        c_fmcw_write(3, 1)
        if output == "raw":
            c_fmcw_write(0, 1)
        elif output == "fir":
            c_fmcw_write(1, 1)
        elif output == "window":
            c_fmcw_write(2, 1)
        else:
            c_fmcw_write(3, 1)

    def _send_start(self):
        c_fmcw_write(0, 1)

    def _send_stop(self):
        c_fmcw_write(0xFF, 1)
