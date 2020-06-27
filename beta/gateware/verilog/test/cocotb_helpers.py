"""
A collection of useful functions for extending cocotb.
"""

import numpy as np

import cocotb
from cocotb import clock
from cocotb.triggers import Timer, RisingEdge


def random_samples(bit_width, num_samples):
    """
    Generate a random sequence of values where each data point in the
    sequence has its range determined by @bit_width.
    """
    seq = np.zeros(num_samples, dtype=int)
    for i, _ in enumerate(seq):
        seq[i] = np.random.randint(-2 ** (bit_width - 1), 2 ** (bit_width - 1))
    return seq.astype(int)


class Clock:
    """
    A wrapper around cocotb.clock.Clock, which provides enhanced
    functionality.
    """

    def __init__(self, clk, freq, phase=0):
        """
        Arguments

        clk: the dut port object for the clock (e.g. dut.clk)
        freq: frequency in MHz
        phase: phase in ns

        Class members

        clk: same as argument
        period: period in ps
        phase: phase in ps
        """
        self.clk = clk
        self.period = 1e6 / freq
        self.phase = 1e3 * phase

    def scale(self, factor):
        """Scale the clock period and phase shift by @factor."""
        self.period *= factor
        self.phase *= factor

    @cocotb.coroutine
    async def start(self):
        """
        Generates a clock signal for clock. This is analagous to
        cocotb.clock.Clock.start(), but with the enhanced flexibility
        of this Clock class.
        """
        self.clk <= 0
        await Timer(self.period / 2 - self.phase)
        while True:
            self.clk <= 1
            await Timer(self.period / 2)
            self.clk <= 0
            await Timer(self.period / 2)


class ClockEnable:
    """
    Generates a clock enable signal based on an underlying clock
    signal.
    """

    def __init__(self, clk, clk_en, rst_n, freq_ratio):
        """
        @clk is the underlying base Clock object.

        @clk_en is the device under test clock enable port.

        @freq_ratio is the ratio of the frequency of the base clock to
        the frequency of the clock enable signal.
        """
        self.clk = clk
        self.clk_en = clk_en
        self.rst_n = rst_n
        self.freq_ratio = freq_ratio

    @cocotb.coroutine
    async def start(self):
        ctr = 0
        await RisingEdge(self.rst_n)
        while True:
            if ctr == self.freq_ratio - 1:
                ctr = 0
                self.clk_en <= 1
            else:
                ctr = ctr + 1
                self.clk_en <= 0
            await RisingEdge(self.clk)


def check_periods_integral(periods):
    """
    Test whether supplied list of clock periods are of integral
    value.
    """
    delta = 0.1
    for period in periods:
        if abs(period - round(period)) > delta:
            return False

    return True


class MultiClock:
    """
    A Clock wrapper for multiclock designs. This can be used to
    synchronize multiple clocks.
    """

    def __init__(self, clocks):
        """
        clocks: A list of Clock objects. The clock frequencies and phase
        shift will be adjusted if necessary in order to be mutually
        combatible and able to be simulated (due to ps precision).
        """
        self.clocks = clocks
        self._normalize_periods_for_simulation()
        self.align_first_posedge()

    def clock_periods(self):
        """Retrieve list of all clock periods."""
        return [clk.period for clk in self.clocks]

    def _normalize_periods_for_simulation(self):
        """
        Scale clock periods so they can be accurately represented with ps
        resolution.
        """
        periods = self.clock_periods()
        if not check_periods_integral(periods):
            min_p = min(periods)
            # keep the period in ps
            norm_periods = [1e3 * p / min_p for p in periods]
            periods = norm_periods
            while True:
                if not check_periods_integral(periods):
                    periods = [sum(x) for x in zip(periods, norm_periods)]
                else:
                    break

        for clk, period in zip(self.clocks, periods):
            clk.scale(int(round(period)) / clk.period)

    def align_first_posedge(self):
        """
        Set the first positive edge of all clocks to occur at the same
        time.
        """
        min_half_period = min([clk.period / 2 for clk in self.clocks])
        for clk in self.clocks:
            clk.phase = clk.period / 2 - min_half_period

    def start_all_clocks(self):
        """Generates a clock signal for all clocks."""
        for clk in self.clocks:
            cocotb.fork(clk.start())

    def max_period(self):
        """
        Return the max period of all clocks. This is useful for ensuring
        resets are registered by memory elements in all clock domains.
        """
        return max([clk.period for clk in self.clocks])
