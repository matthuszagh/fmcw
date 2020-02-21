#!/usr/bin/env python
"""
Cocotb unit test for ft245.v

In order to simplify this module, the host PC takes on the
responsibilities of the FT2232H chip in addition to its own. Namely,
it sets the rxf_n, txe_n, and suspend_n lines. It may also drive the
ft_data line if a PC -> FPGA transmission is being simulated.
"""

import numpy as np

from cocotb_helpers import Clock, MultiClock, random_samples
import bit

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, Combine
from cocotb.result import TestFailure
from cocotb.binary import BinaryValue


class FT245_TB:
    """
    FT2232H FT245 asynchronous mode FIFO testbench class.
    """

    def __init__(self, dut):
        clk = Clock(dut.clk, 40)
        ft_clk = Clock(dut.ft_clk, 60)
        slow_ft_clk = Clock(dut.slow_ft_clk, 7.5)
        self.multiclock = MultiClock([clk, ft_clk, slow_ft_clk])
        self.dut = dut

    @cocotb.coroutine
    async def setup(self):
        self.multiclock.start_all_clocks()
        await self.reset()

    @cocotb.coroutine
    async def reset(self):
        await self.await_all_clocks()
        self.dut.rst_n <= 0
        await self.await_all_clocks()
        self.dut.rst_n <= 1

    @cocotb.coroutine
    async def await_all_clocks(self):
        trigs = []
        for clk in self.multiclock.clocks:
            trigs.append(RisingEdge(clk.clk))

        await Combine(*trigs)

    @cocotb.coroutine
    async def fpga_write_continuous(self, inputs):
        """
        Continuously write from FPGA. When inputs have been exhausted,
        write zeros.
        """
        sample_ctr = 0
        num_samples = len(inputs)
        self.dut.wren <= 1
        while True:
            if sample_ctr < num_samples:
                self.dut.wrdata <= BinaryValue(
                    int(inputs[sample_ctr].item()), 64, binaryRepresentation=2
                )
            else:
                self.dut.wrdata <= 0
            sample_ctr += 1
            await RisingEdge(self.dut.clk)

    # @cocotb.coroutine
    # async def pc_read_continuous(self):
    #     """
    #     Continuously read data from the FT2232H to the host PC.
    #     """


# TODO
@cocotb.test()
async def fpga_write_sequence(dut):
    """
    Write a series of values from the FPGA to the FT245 and ensure the
    correct data is written to the FT2232H data bus.
    """
    ft245 = FT245_TB(dut)
    await ft245.setup()

    num_writes = 1000
    input_width = 64

    wrdata = random_samples(input_width, num_writes)
    cocotb.fork(ft245.fpga_write_continuous(wrdata))

    ft245.dut.txe_n <= 0
    ft245.dut.rxf_n <= 1
    ft245.dut.suspend_n <= 1

    i = 0
    while i < num_writes:
        await ReadOnly()
        # print(wrdata[i])
        # print(ft245.dut.ft_data)

        await RisingEdge(ft245.dut.ft_clk)
        i += 1
