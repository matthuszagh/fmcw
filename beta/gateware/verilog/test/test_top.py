#!/usr/bin/env python
"""
Unit tests for top module.
"""

import numpy as np

from cocotb_helpers import MultiClock, Clock, ClockEnable, random_samples
from fir import FIR
import bit

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly
from cocotb.result import TestFailure


class TopTb:
    """
    Top testbench class.
    """

    def __init__(self, dut):
        self.clk = Clock(dut.clk_i, 40)
        self.clk10 = Clock(dut.clk10, 10)
        self.clk20 = Clock(dut.clk20, 20)
        self.clk80 = Clock(dut.clk80, 80)
        self.multiclock = MultiClock(
            [self.clk, self.clk10, self.clk20, self.clk80]
        )
        self.clk_en = ClockEnable(dut.clk_i, dut.clk2_pos_en, 20)
        self.clk60 = Clock(dut.ft_clkout_i, 60)
        self.dut = dut
        self.inputs = []
        # self.inputs = random_samples(12, 20480)

    @cocotb.coroutine
    async def setup(self):
        """
        """
        self.multiclock.start_all_clocks()
        cocotb.fork(self.clk_en.start())
        cocotb.fork(self.clk60.start())
        self.dut.ft_suspend_n_i.setimmediatevalue(1)
        self.dut.adc_of_i.setimmediatevalue(0)
        cocotb.fork(self.gen_muxout())
        cocotb.fork(self.gen_ft_txe())

    @cocotb.coroutine
    async def gen_muxout(self):
        """
        """
        self.dut.adf_muxout_i.setimmediatevalue(1)
        ctr = 0
        low_ctr_max = 40000
        high_ctr_max = 80000
        while True:
            if (
                self.dut.adf_active.value.is_resolvable
                and self.dut.adf_active.value.integer == 1
            ):
                if self.dut.adf_muxout_i.value.is_resolvable:
                    if self.dut.adf_muxout_i.value.integer == 1:
                        if ctr == high_ctr_max - 1:
                            ctr = 0
                            self.dut.adf_muxout_i <= 0
                        else:
                            ctr += 1
                    else:
                        if ctr == low_ctr_max - 1:
                            ctr = 0
                            self.dut.adf_muxout_i <= 1
                        else:
                            ctr += 1
            await RisingEdge(self.dut.clk_i)

    @cocotb.coroutine
    async def gen_ft_txe(self):
        """
        """
        ctr = 0
        self.dut.ft_txe_n_i.setimmediatevalue(0)
        while True:
            if (
                self.dut.ft_txe_n_i.value.is_resolvable
                and self.dut.ft_txe_n_i.value.integer == 0
            ):
                if ctr == 500:
                    self.dut.ft_txe_n_i <= 1
                    ctr = 0
                else:
                    ctr += 1
            else:
                if ctr == 5:
                    self.dut.ft_txe_n_i <= 0
                    ctr = 0
                else:
                    ctr += 1
            await RisingEdge(self.dut.ft_clkout_i)

    @cocotb.coroutine
    async def write_continuous(self):
        """
        """
        bit_width = 12
        while True:
            self.dut.adc_d_i <= np.random.randint(
                -(2 ** (bit_width - 1)), 2 ** (bit_width - 1) - 1
            )
            await RisingEdge(self.dut.clk_i)

    @cocotb.coroutine
    async def write_configuration(self):
        """
        """
        cfg_ctr = 0
        cfg_arr = [
            # chan A
            0x01,
            0x00,
            # chan B
            0x02,
            0x01,
            # output
            0x03,
            0x03,
            # adf reg 0
            0x80,
            0x00,
            0x00,
            0x8C,
            0x78,
            # adf reg 1
            0x81,
            0x01,
            0x00,
            0x00,
            0x00,
            # adf reg 2
            0x82,
            0x52,
            0x80,
            0x60,
            0x10,
            # adf reg 3
            0x83,
            0x43,
            0x80,
            0x00,
            0x00,
            # adf reg 4
            0x84,
            0x84,
            0x00,
            0x78,
            0x00,
            # adf reg 5
            0x85,
            0x85,
            0x00,
            0x20,
            0x00,
            # adf reg 6
            0x86,
            0x86,
            0x3E,
            0x00,
            0x00,
            # adf reg 7
            0x87,
            0x07,
            0x7D,
            0x03,
            0x00,
            # start
            0x00,
        ]
        while cfg_ctr < len(cfg_arr):
            self.dut.ft_rxf_n_i <= 0
            self.dut.ft_data_io <= cfg_arr[cfg_ctr]
            if (
                self.dut.ft_oe_n_o.value.is_resolvable
                and self.dut.ft_oe_n_o.value.integer == 0
                and self.dut.ft_rd_n_o.value.is_resolvable
                and self.dut.ft_rd_n_o.value.integer == 0
            ):
                cfg_ctr += 1
            await RisingEdge(self.dut.ft_clkout_i)

        self.dut.ft_rxf_n_i.setimmediatevalue(1)

    @cocotb.coroutine
    async def gen_inputs(self):
        """
        """
        input_len = 20480
        input_valid = False
        start_capture = False
        muxout = self.dut.adf_muxout_i
        clk2_pos_en = self.dut.clk2_pos_en

        while len(self.inputs) < input_len:
            if (
                clk2_pos_en.value.is_resolvable
                and clk2_pos_en.value.integer == 1
            ):
                start_capture = True

            await RisingEdge(self.dut.clk_i)

            if start_capture:
                if not input_valid:
                    if (
                        len(self.inputs) == 20
                        and muxout.value.is_resolvable
                        and muxout.value.integer == 0
                    ):
                        input_valid = True
                    elif len(self.inputs) == 20:
                        self.inputs = []

                self.inputs.append(
                    self.dut.adc_single_chan.value.signed_integer
                )

        self.outputs = self.gen_outputs()

    def gen_outputs(self):
        """
        Generate expected outputs.
        """
        fir = FIR(
            numtaps=120,
            bands=[0, 0.5e6, 1e6, 20e6],
            band_gain=[1, 0],
            fs=40e6,
            pass_db=0.5,
            stop_db=-40,
        )
        taps = fir.taps
        downsample_factor = 20
        out_pre_dec = np.convolve(self.inputs, taps)
        out_pre_dec = out_pre_dec[: len(self.inputs)]
        # use convergent rounding
        self.fir_outputs = [
            out_pre_dec[i]
            for i in range(len(out_pre_dec))
            if i % downsample_factor == 0
        ]
        window_coeffs = np.kaiser(1024, 6)
        self.window_outputs = self.fir_outputs * window_coeffs
        outputs = np.fft.fft(self.window_outputs)
        return outputs
        # # Drop the first value. This ensures that the first output
        # # gets the full 2MHz cycle of inputs.
        # return outputs[1:]

    def check_fir_output(self, ctr: int, tol: float) -> None:
        """
        """
        exp_val = self.fir_outputs[ctr]
        act_val = self.dut.fir_out.value.signed_integer
        if abs(exp_val - act_val) > tol:
            raise TestFailure(
                (
                    "Actual fir output differs from expected."
                    " Actual: %d, expected: %d, difference: %d."
                    " Tolerance set at %d. Counter value %d."
                )
                % (act_val, exp_val, act_val - exp_val, tol, ctr)
            )
        print(ctr, ":", act_val, "(act)", exp_val, "(exp)")

    def check_window_output(self, ctr: int, tol: float) -> None:
        """
        """
        exp_val = self.window_outputs[ctr]
        act_val = self.dut.window_out.value.signed_integer
        if abs(exp_val - act_val) > tol:
            raise TestFailure(
                (
                    "Actual window output differs from expected."
                    " Actual: %d, expected: %d, difference: %d."
                    " Tolerance set at %d. Counter value %d."
                )
                % (act_val, exp_val, act_val - exp_val, tol, ctr)
            )

    def check_fft_output(self, tol: float) -> None:
        """
        """
        ctr = self.dut.fft_ctr.value.integer
        exp_val = self.outputs[ctr]
        re_exp_val = np.real(exp_val)
        im_exp_val = np.imag(exp_val)

        re_act_val = self.dut.fft_re_o.value.signed_integer
        im_act_val = self.dut.fft_im_o.value.signed_integer

        if abs(re_exp_val - re_act_val) > tol:
            raise TestFailure(
                (
                    "Actual real fft output differs from expected."
                    " Actual: %d, expected: %d, difference: %d."
                    " Tolerance set at %d. Counter value %d."
                )
                % (re_act_val, re_exp_val, re_act_val - re_exp_val, tol, ctr)
            )

        if abs(im_exp_val - im_act_val) > tol:
            raise TestFailure(
                (
                    "Actual imaginary fft output differs from expected."
                    " Actual: %d, expected: %d, difference: %d."
                    " Tolerance set at %d. Counter value %d."
                )
                % (im_act_val, im_exp_val, im_act_val - im_exp_val, tol, ctr)
            )


@cocotb.test()
async def check_sequence(dut):
    """
    Compare the output from a randomly-generated sequence with scipy.
    """
    num_samples = 20480
    tb = TopTb(dut)
    await tb.setup()
    await tb.write_configuration()
    cocotb.fork(tb.write_continuous())
    await tb.gen_inputs()

    fir_tol = 1
    fir_ctr = 0
    fir_ctr_max = 1024

    window_tol = 1
    window_ctr = 0
    window_ctr_max = 1024

    fft_tol = 20
    fft_ctr = 0
    fft_ctr_max = 1024

    while (
        fir_ctr < fir_ctr_max
        or window_ctr < window_ctr_max
        or fft_ctr < fft_ctr_max
    ):
        await ReadOnly()

        if (
            fir_ctr < fir_ctr_max
            and tb.dut.fir_dvalid.value.integer == 1
            and tb.dut.fir.tap_addr.value.integer == 0
        ):
            tb.check_fir_output(fir_ctr, fir_tol)
            fir_ctr += 1

        if (
            window_ctr < window_ctr_max
            and tb.dut.window_dvalid.value.integer == 1
            and tb.dut.fir.tap_addr.value.integer == 0
        ):
            tb.check_window_output(window_ctr, window_tol)
            window_ctr += 1

        if fft_ctr < fft_ctr_max and tb.dut.fft_valid.value.integer == 1:
            tb.check_fft_output(fft_tol)
            fft_ctr += 1

        await RisingEdge(dut.clk_i)

    # i = 0
    # while i < num_samples:
    #     print("input ", i, ": ", tb.inputs[i])
    #     i += 1

    # i = 0
    # while i < 1024:
    #     print("fir output ", i, ": ", int(round(tb.fir_outputs[i])))
    #     i += 1

    # i = 0
    # while i < 1024:
    #     print("window output ", i, ": ", int(round(tb.window_outputs[i])))
    #     i += 1

    # tol = 20
    # i = len(tb.outputs)
    # rdiffs = []
    # idiffs = []

    # while i > 0:
    #     await ReadOnly()
    #     if (
    #         dut.ft_txe_n_i.value.is_resolvable
    #         and dut.ft_txe_n_i.value.integer == 0
    #         and dut.ft_wr_n_o.value.is_resolvable
    #         and dut.ft_wr_n_o.value.integer == 0
    #     ):
    #         print(
    #             "output ",
    #             len(tb.outputs) - i,
    #             ": ",
    #             tb.outputs[len(tb.outputs) - i],
    #         )
    #         i -= 1
    #     await RisingEdge(dut.clk_i)
