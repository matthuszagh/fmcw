#!/usr/bin/env python
"""
Unit tests for shift_reg.v
"""

import random

from cocotb_helpers import Clock

import cocotb
from cocotb.result import TestFailure
from cocotb.triggers import RisingEdge, ReadOnly

DATA_WIDTH = 25
LEN = 512


class ShiftRegTB:
    def __init__(self, dut):
        self.clk = Clock(dut.clk, 40)
        self.dut = dut

    @cocotb.coroutine
    async def setup(self):
        cocotb.fork(self.clk.start())
        await self.reset()
        self.dut.ce <= 1

    @cocotb.coroutine
    async def reset(self):
        await RisingEdge(self.dut.clk)
        self.dut.rst_n <= 0
        await RisingEdge(self.dut.clk)
        self.dut.rst_n <= 1


@cocotb.test()
async def check_rand_seq(dut):
    tb = ShiftRegTB(dut)
    await tb.setup()
    inputs = [random.randint(0, 2 ** DATA_WIDTH - 1) for i in range(LEN)]
    ts = 0
    while ts < LEN:
        tb.dut.di <= inputs[ts]
        await RisingEdge(tb.dut.clk)
        ts += 1

    ts = 0
    while ts < LEN:
        await ReadOnly()
        rdval = tb.dut.data_o.value.integer
        if rdval != inputs[ts]:
            raise TestFailure(
                ("Input/output values differ. Write: %d, read: %d.")
                % (inputs[ts], rdval)
            )
        await RisingEdge(tb.dut.clk)
        ts += 1
