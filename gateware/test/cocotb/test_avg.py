#!/usr/bin/env python
"""
Unit tests for fir.
"""

import numpy as np

from cocotb_helpers import Clock, ClockEnable, random_samples

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly
from cocotb.result import TestFailure


class AVGTB:
    """
    avg.v testbench.
    """

    def __init__(self, dut, size, width, lg_n):
        """
        """
        self.clk = Clock(dut.clk, 40)
        self.clken = ClockEnable(dut.clk, dut.clken, dut.rst_n, 20)
        self.dut = dut
        self.inputs = [random_samples(width, size) for _ in range(2 ** lg_n)]
        self.outputs = self.gen_outputs()

    @cocotb.coroutine
    async def setup(self):
        """
        """
        cocotb.fork(self.clk.start())
        cocotb.fork(self.clken.start())
        await self.reset()

    @cocotb.coroutine
    async def reset(self):
        """
        """
        await RisingEdge(self.dut.clk)
        self.dut.rst_n <= 0
        await RisingEdge(self.dut.clk)
        self.dut.rst_n <= 1

    @cocotb.coroutine
    async def write_continuous(self):
        """
        Continously write inputs.
        """
        seq_ctr = 0
        num_seq = len(self.inputs)
        sample_ctr = 0
        num_samples = len(self.inputs[0])

        while True:
            await FallingEdge(self.dut.clken)
            if seq_ctr < num_seq:
                self.dut.en <= 1
                self.dut.din <= self.inputs[seq_ctr][sample_ctr].item()
                if sample_ctr == num_samples - 1:
                    sample_ctr = 0
                    seq_ctr += 1
                else:
                    sample_ctr += 1
            else:
                self.dut.din <= 0

    def gen_outputs(self):
        """
        """
        return np.average(self.inputs, axis=0)


@cocotb.test()
async def check_sequence(dut):
    """
    """
    tb = AVGTB(dut, 1024, 16, 2)
    await tb.setup()

    cocotb.fork(tb.write_continuous())

    tol = 1
    i = len(tb.outputs)
    diffs = []
    while i > 0:
        await FallingEdge(tb.dut.clken)
        await ReadOnly()
        if tb.dut.dvalid.value.integer:
            out_val = tb.dut.dout.value.signed_integer
            out_exp = tb.outputs[len(tb.outputs) - i]
            diffs.append(out_val - out_exp)
            if abs(out_val - out_exp) > tol:
                raise TestFailure(
                    (
                        "Actual output differs from expected."
                        " Actual: %d, expected: %d. Tolerance set at %d."
                    )
                    % (out_val, out_exp, tol)
                )

            i -= 1
