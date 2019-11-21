#!/usr/bin/env python
"""
Automated tests for top-level module.
"""


import numpy as np

from libdigital.tools.cocotb_helpers import Clock, MultiClock, random_samples
from libdigital.tools import bit

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, Combine, Timer
from cocotb.result import TestFailure
from cocotb.binary import BinaryValue


class TopTB:
    def __init__(self, dut):
        clk = Clock(dut.clk_i, 40)
        clk_7_5 = Clock(dut.clk_7_5mhz, 7.5)
        clk_120 = Clock(dut.clk_120mhz, 120)
        clk_80 = Clock(dut.clk_80mhz, 80)
        clk_20 = Clock(dut.clk_20mhz, 20)
        ftclk = Clock(dut.ft_clkout_i, 60)
        self.multiclock = MultiClock(
            [clk, clk_7_5, clk_120, clk_80, clk_20, ftclk]
        )
        self.dut = dut

    @cocotb.coroutine
    async def setup(self):
        self.multiclock.start_all_clocks()
        self.dut.ft_rxf_n_i <= 1
        self.dut.ft_txe_n_i <= 1
        self.dut.ft_suspend_n_i <= 1
        await self.reset()

    @cocotb.coroutine
    async def reset(self):
        await self.await_all_clocks()
        self.dut.pll_lock <= 0
        await self.await_all_clocks()
        self.dut.pll_lock <= 1

    @cocotb.coroutine
    async def await_all_clocks(self):
        trigs = []
        for clk in self.multiclock.clocks:
            trigs.append(RisingEdge(clk.clk))

        await Combine(*trigs)

    @cocotb.coroutine
    async def rand_lose_lock(self):
        """
        Simulate random loss of PLL lock. This attempts to be somewhat
        physically accurate by mainting the lock for longer periods
        than it is lost.
        """
        time_unit = min(self.multiclock.clock_periods())
        while True:
            time_on = np.random.randint(
                1e3 * time_unit, 1e4 * time_unit, dtype=int
            )
            await Timer(time_on)
            self.dut.pll_lock <= 0
            time_off = np.random.randint(
                1e1 * time_unit, 1e2 * time_unit, dtype=int
            )
            await Timer(time_off)
            self.dut.pll_lock <= 1

    @cocotb.coroutine
    # TODO add samples on falling edge for chan b
    async def gen_samples(self, inputs):
        sample_ctr = 0
        num_samples = len(inputs)
        while True:
            if sample_ctr == num_samples:
                sample_ctr = 0

            self.dut.adc_d_i <= BinaryValue(
                int(inputs[sample_ctr].item()), 12, binaryRepresentation=2
            )
            sample_ctr += 1
            await RisingEdge(self.dut.clk_i)


@cocotb.test()
async def rand_samples(dut):
    top = TopTB(dut)
    await top.setup()

    num_writes = 100000
    input_width = 7

    wrdata = random_samples(input_width, num_writes)
    cocotb.fork(top.gen_samples(wrdata))
    top.dut.ft_rxf_n_i <= 0
    top.dut.ft_data_io <= 1
    await RisingEdge(top.dut.ft_clkout_i)
    top.dut.ft_data_io <= 1
    await RisingEdge(top.dut.ft_clkout_i)
    top.dut.ft_rxf_n_i <= 1
    await RisingEdge(top.dut.ft_clkout_i)

    top.dut.ft_txe_n_i <= 0
    i = 0
    while i < num_writes:
        # await ReadOnly()
        # print(wrdata[i])
        # print(top.dut.ft_data_io)

        await RisingEdge(top.dut.ft_clkout_i)
        i += 1
