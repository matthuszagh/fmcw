#!/usr/bin/env python
"""
Unit tests for R2^2 SDF FFT.
"""

import numpy as np

import bit
from fft import FFT
from cocotb_helpers import Clock, MultiClock, random_samples

import cocotb
from cocotb.result import TestFailure
from cocotb.triggers import RisingEdge, ReadOnly, Combine, Timer
from cocotb.binary import *


class FFTTB:
    """
    R22 SDF FFT testbench class.
    """

    def __init__(
        self,
        dut,
        num_samples,
        input_width,
        twiddle_width,
        discretize_twiddles: bool = False,
        use_max: bool = False,
    ):
        clk = Clock(dut.clk, 40)
        self.clk = clk
        self.dut = dut
        self.twiddle_width = twiddle_width
        self.discretize_twiddles = discretize_twiddles
        self.length = num_samples
        if use_max:
            self.re_inputs = np.array(
                [2 ** (input_width - 1) - 1 for _ in range(num_samples)]
            )
            self.im_inputs = np.array(
                [2 ** (input_width - 1) - 1 for _ in range(num_samples)]
            )
        else:
            self.re_inputs = random_samples(input_width, num_samples)
            self.im_inputs = random_samples(input_width, num_samples)
        self.gen_outputs()

    def gen_outputs(self) -> None:
        """
        """
        if self.discretize_twiddles:
            real_prec_twiddles = np.zeros(
                (self.length, self.length), dtype=np.cdouble
            )
            quantized_twiddles = np.zeros(
                (self.length, self.length), dtype=np.cdouble
            )
            self.outputs = np.zeros(self.length, dtype=np.cdouble)
            for k in range(self.length):
                for n in range(self.length):
                    real_prec_twiddles[k][n] = np.exp(
                        -2 * np.pi * 1j * n * k / self.length
                    )
                    quantized_twiddles[k][n] = bit.quantized_complex(
                        real_prec_twiddles[k][n], self.twiddle_width
                    )
                    self.outputs[k] += (
                        self.re_inputs[n] + 1j * self.im_inputs[n]
                    ) * quantized_twiddles[k][n]

        else:
            self.outputs = np.fft.fft(self.re_inputs + 1j * self.im_inputs)

    @cocotb.coroutine
    async def setup(self):
        cocotb.fork(self.clk.start())

    def check_outputs(self, tolerance):
        """
        Check that the measured outputs are within the specified tolerance
        of the actual outputs. Raise a test failure if not. If the
        tolerance is satisfied, return a tuple of the difference
        values.
        """
        bit_rev_ctr = self.dut.data_ctr_o.value.integer
        rval = self.dut.data_re_o.value.signed_integer
        rexp = np.real(self.outputs)[bit_rev_ctr].item()
        rdiff = rval - rexp
        ival = self.dut.data_im_o.value.signed_integer
        iexp = np.imag(self.outputs)[bit_rev_ctr].item()
        idiff = ival - iexp
        if abs(rval - rexp) > tolerance:
            raise TestFailure(
                (
                    "Actual real output differs from expected."
                    " Actual: %d, expected: %d, difference: %d."
                    " Tolerance set at %d."
                )
                % (rval, rexp, rval - rexp, tolerance)
            )

        if abs(ival - iexp) > tolerance:
            raise TestFailure(
                (
                    "Actual imaginary output differs from expected."
                    " Actual: %d, expected: %d, difference: %d."
                    " Tolerance set at %d."
                )
                % (ival, iexp, ival - iexp, tolerance)
            )

        return (rdiff, idiff)

    @cocotb.coroutine
    async def write_inputs(self):
        """
        Send all calculated inputs to dut.
        """
        ctr = 0
        num_samples = len(self.re_inputs)
        while True:
            if ctr < num_samples:
                self.dut.en <= 1
                self.dut.data_re_i <= self.re_inputs[ctr].item()
                self.dut.data_im_i <= self.im_inputs[ctr].item()
            else:
                self.dut.en <= 0
                self.dut.data_re_i <= 0
                self.dut.data_im_i <= 0

            await RisingEdge(self.dut.clk)
            ctr += 1


@cocotb.test()
async def check_sequence(dut):
    """
    Compare the hdl FFT output with numpy, to within some specified tolerance.
    """
    num_samples = 1024
    input_width = 13
    twiddle_width = 18
    fft = FFTTB(
        dut,
        num_samples,
        input_width,
        twiddle_width,
        discretize_twiddles=False,
        use_max=False,
    )
    await fft.setup()
    cocotb.fork(fft.write_inputs())

    tol = 20
    rdiffs = []
    idiffs = []

    i = num_samples
    while i > 0:
        await ReadOnly()
        if fft.dut.valid.value.integer:
            (rval, ival) = fft.check_outputs(tol)
            rdiffs.append(rval)
            idiffs.append(ival)
            # print(num_samples - 1 - i, " (real): ", int(rval))
            # print(num_samples - 1 - i, " (imag): ", int(ival))

            i -= 1
        await RisingEdge(fft.dut.clk)

    avg_tol = 1
    if abs(np.average(rdiffs)) > avg_tol:
        raise TestFailure(
            (
                "Average real outputs differ from expected more than"
                " tolerated. There might be a bias. Difference %f."
                " Tolerated: %f"
            )
            % (np.average(rdiffs), avg_tol)
        )
    if abs(np.average(idiffs)) > avg_tol:
        raise TestFailure(
            (
                "Average imaginary outputs differ from expected more than"
                " tolerated. There might be a bias. Difference %f."
                " Tolerated: %f"
            )
            % (np.average(idiffs), avg_tol)
        )


# @cocotb.test()
# async def rand_resets(dut):
#     """
#     Test the FFT's behavior when sending intermittent reset signals.
#     """
#     num_samples = 100000
#     input_width = 14
#     fft = FFTTB(dut, num_samples, input_width)
#     await fft.setup()
#     cocotb.fork(fft.write_inputs())
#     cocotb.fork(fft.send_intermittent_resets())
#     while True:
#         await RisingEdge(fft.dut.clk)
