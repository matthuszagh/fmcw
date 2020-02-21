#!/usr/bin/env python
"""
Unit tests for fir.
"""

import numpy as np
from scipy import signal

from cocotb_helpers import Clock, ClockEnable, random_samples
from fir import FIR
import bit

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly
from cocotb.result import TestFailure


class FIRTB:
    """
    FIR testbench class.
    """

    def __init__(self, dut, num_samples, input_width, tap_width):
        self.clk = Clock(dut.clk, 40)
        self.clk_en = ClockEnable(dut.clk, dut.clk_2mhz_pos_en, dut.rst_n, 20)
        self.dut = dut
        self.inputs = random_samples(input_width, num_samples)
        self.downsample_factor = 20
        self.fir = FIR(
            numtaps=120,
            bands=[0, 0.95e6, 1e6, 20e6],
            band_gain=[1, 0],
            fs=40e6,
            pass_db=0.5,
            stop_db=-40,
        )
        self.taps = self.fir.taps
        self.outputs = self.gen_outputs()

    @cocotb.coroutine
    async def setup(self):
        """
        Initialize FIR filter in a defined state.
        """
        cocotb.fork(self.clk.start())
        cocotb.fork(self.clk_en.start())
        await self.reset()

    @cocotb.coroutine
    async def reset(self):
        """
        Assert a reset and ensure it's registered by the clock.
        """
        await RisingEdge(self.dut.clk)
        self.dut.rst_n <= 0
        await RisingEdge(self.dut.clk)
        self.dut.rst_n <= 1

    @cocotb.coroutine
    async def write_continuous(self):
        """
        Continously write inputs. When inputs have been exhausted, write
        zeros.
        """
        sample_ctr = 0
        num_samples = len(self.inputs)
        while True:
            if sample_ctr < num_samples:
                self.dut.din <= self.inputs[sample_ctr].item()
            else:
                self.dut.din <= 0
            sample_ctr += 1
            await RisingEdge(self.dut.clk)

    def gen_outputs(self):
        """
        Generate expected outputs.
        """
        out_pre_dec = np.convolve(self.inputs, self.taps)
        # use convergent rounding
        outputs = [
            out_pre_dec[i]
            # int(np.around(out_pre_dec[i]))
            for i in range(len(out_pre_dec))
            if i % self.downsample_factor == 0
        ]
        # Drop the first value. This ensures that the first output
        # gets the full 2MHz cycle of inputs.
        return outputs[1:]


@cocotb.test()
async def check_sequence(dut):
    """
    Compare the output from a randomly-generated sequence with scipy.
    """
    num_samples = 10000
    input_width = 12
    tap_width = 16
    tb = FIRTB(dut, num_samples, input_width, tap_width)
    await tb.setup()

    cocotb.fork(tb.write_continuous())

    tol = 1
    i = len(tb.outputs)
    clk_en_ctr = 0
    diffs = []
    while i > 0:
        await FallingEdge(tb.dut.clk_2mhz_pos_en)
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

    avg_tol = 0.3
    abs_avg_diff = np.average(np.abs(diffs))
    avg_diff = abs(np.average(diffs))

    if avg_diff > avg_tol:
        raise TestFailure(
            (
                "Average deviation of %f further from zero than"
                " expected. There might be a bias. Tolerance: %f."
            )
            % (avg_diff, avg_tol)
        )

    if abs_avg_diff > 2 * avg_tol:
        raise TestFailure(
            (
                "Average absolute deviation of %f further from zero than"
                " expected. There might be a problem. Tolerance: %f."
            )
            % (abs_avg_diff, 2 * avg_tol)
        )


@cocotb.test()
async def bank_output_vals(dut):
    """
    Ensure the bank output values are correct at all points time.
    """
    num_samples = 10000
    input_width = 12
    tap_width = 16
    tb = FIRTB(dut, num_samples, input_width, tap_width)
    await tb.setup()
    norm_shift = 3

    cocotb.fork(tb.write_continuous())

    # we can't use len(tb.outputs) here since we want 500 and that
    # gives 506 due to the resultant length of a convolution
    num_outputs = int(num_samples / tb.downsample_factor)
    i = num_outputs
    bank_outs = np.zeros(tb.downsample_factor, dtype=int)
    while i > 0:
        outputs_count_up = num_outputs - i
        cur_input_index = tb.downsample_factor * outputs_count_up
        min_idx = max(cur_input_index - 119, 0)
        max_idx = min(min_idx + 119, cur_input_index)
        last_120_inputs_indices = np.linspace(
            max_idx, min_idx, max_idx - min_idx + 1, dtype=int
        )
        bank_outs.fill(0)

        for j, input_index in enumerate(last_120_inputs_indices):
            bank_outs[(20 - (input_index % 20)) % 20] += tb.inputs[
                input_index
            ] * bit.sub_integral_to_sint(
                tb.fir.taps[j] * (2 ** norm_shift), tap_width
            )

        await RisingEdge(tb.dut.clk_2mhz_pos_en)
        await ReadOnly()
        bank_output_vars = [
            tb.dut.bank0.dout,
            tb.dut.bank1.dout,
            tb.dut.bank2.dout,
            tb.dut.bank3.dout,
            tb.dut.bank4.dout,
            tb.dut.bank5.dout,
            tb.dut.bank6.dout,
            tb.dut.bank7.dout,
            tb.dut.bank8.dout,
            tb.dut.bank9.dout,
            tb.dut.bank10.dout,
            tb.dut.bank11.dout,
            tb.dut.bank12.dout,
            tb.dut.bank13.dout,
            tb.dut.bank14.dout,
            tb.dut.bank15.dout,
            tb.dut.bank16.dout,
            tb.dut.bank17.dout,
            tb.dut.bank18.dout,
            tb.dut.bank19.dout,
        ]

        for bank in range(tb.downsample_factor):
            bank_out = bank_output_vars[bank].value.signed_integer
            exp_out = bank_outs[bank]
            if bank_out != exp_out:
                raise TestFailure(
                    (
                        "Actual bank %d output differs from expected."
                        " Actual: %d, expected: %d."
                    )
                    % (bank, bank_out, exp_out)
                )

        i -= 1
