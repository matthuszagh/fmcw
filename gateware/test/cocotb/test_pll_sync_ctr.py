#!/usr/bin/env python
"""
Unit tests for pll_sync_ctr.v module.
"""

from cocotb_helpers import Clock, MultiClock

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, Combine, Timer


class PllSyncCtrTB:
    def __init__(self, dut):
        fst_clk = Clock(dut.fst_clk, 80)
        slw_clk = Clock(dut.slw_clk, 10)
        self.multiclock = MultiClock([fst_clk, slw_clk])
        self.dut = dut

    @cocotb.coroutine
    async def setup(self):
        self.multiclock.start_all_clocks()
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


@cocotb.test()
async def check_ctr(dut):
    tb = PllSyncCtrTB(dut)
    await tb.setup()

    i = 0
    while i < 10000:
        await RisingEdge(tb.dut.fst_clk)
        i += 1
