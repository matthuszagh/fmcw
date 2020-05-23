#!/usr/bin/env python

import argparse
import os
from enum import Enum, unique
from nmigen.vendor.xilinx_7series import Xilinx7SeriesPlatform
from nmigen.build import Resource, Pins, Clock, Attrs, Subsignal
from nmigen import (
    Module,
    Elaboratable,
    Signal,
    ClockDomain,
    ClockSignal,
    Instance,
    Cat,
    Const,
)
from nmigen.lib.fifo import AsyncFIFO
from nmigen.lib.cdc import FFSynchronizer
from nmigen.back.pysim import Simulator
from ltc2292 import LTC2292


class FMCWRadar(Xilinx7SeriesPlatform):
    """
    """

    device = "XC7A15T"
    package = "FTG256"
    speed = "1"

    resources = [
        Resource(
            "clk40",
            0,
            Pins("N11", dir="i"),
            Clock(40e6),
            Attrs(IOSTANDARD="LVCMOS33"),
        ),
        Resource(
            "ft_data_io",
            0,
            Pins("F15 G16 G15 F14 E16 E15 D16 D15", dir="io"),
            Attrs(IOSTANDARD="LVCMOS33"),
        ),
        Resource(
            "ft_clkout_i",
            0,
            Pins("A15", dir="i"),
            Clock(60e6),
            Attrs(IOSTANDARD="LVCMOS33"),
        ),
        Resource(
            "ft_wr_n_o", 0, Pins("A14", dir="o"), Attrs(IOSTANDARD="LVCMOS33")
        ),
        Resource(
            "ft_rd_n_o", 0, Pins("B14", dir="o"), Attrs(IOSTANDARD="LVCMOS33")
        ),
        Resource(
            "ft_rxf_n_i", 0, Pins("B16", dir="i"), Attrs(IOSTANDARD="LVCMOS33")
        ),
        Resource(
            "ft_txe_n_i", 0, Pins("B15", dir="i"), Attrs(IOSTANDARD="LVCMOS33")
        ),
        Resource(
            "ft_siwua_n_o",
            0,
            Pins("A13", dir="o"),
            Attrs(IOSTANDARD="LVCMOS33"),
        ),
        Resource(
            "ft_oe_n_o", 0, Pins("A12", dir="o"), Attrs(IOSTANDARD="LVCMOS33")
        ),
        Resource(
            "ft_suspend_n_i",
            0,
            Pins("C16", dir="i"),
            Attrs(IOSTANDARD="LVCMOS33"),
        ),
        Resource(
            "adc_d_i",
            0,
            Pins("L2 K2 K1 J3 H1 H2 H3 G2 G1 F2 E1 E2", dir="i"),
            Attrs(IOSTANDARD="LVCMOS33"),
        ),
        Resource(
            "adc_oe_o",
            0,
            Pins("B2 P1", dir="o"),
            Attrs(IOSTANDARD="LVCMOS33"),
        ),
        Resource(
            "adc_shdn_o",
            0,
            Pins("B1 N2", dir="o"),
            Attrs(IOSTANDARD="LVCMOS33"),
        ),
        Resource("led", 0, Pins("D1", dir="o"), Attrs(IOSTANDARD="LVCMOS33")),
        Resource(
            "ext1",
            0,
            Pins("C11 B10 A9 C12 B9 A8", dir="o"),
            Attrs(IOSTANDARD="LVCMOS33"),
        ),
        Resource(
            "pa_en_n_o", 0, Pins("T2", dir="o"), Attrs(IOSTANDARD="LVCMOS33")
        ),
        Resource(
            "mix_en_n_o", 0, Pins("J4", dir="o"), Attrs(IOSTANDARD="LVCMOS33")
        ),
    ]

    connectors = []

    default_clk = "clk40"

    def toolchain_program(self, products, name):
        # bitstream = products.get("{}.bin".format(name))
        os.system("openocd -f interface.cfg -f program_fpga.cfg")


@unique
class RAW_STATE(Enum):
    PROD = 0
    CONS = 1


class Raw(Elaboratable):
    """
    """

    ADC_WIDTH = 12
    USB_WIDTH = 8
    DECIMATE = 20
    FFT_LEN = 1024
    START_FLAG = 0x5A
    STOP_FLAG = 0xA5

    def elaborate(self, platform):
        """
        """
        m = Module()

        # pins
        ft_clkout_i = platform.request("ft_clkout_i")
        ft_wr_n_o = platform.request("ft_wr_n_o")
        ft_txe_n_i = platform.request("ft_txe_n_i")
        ft_suspend_n_i = platform.request("ft_suspend_n_i")
        ft_oe_n_o = platform.request("ft_oe_n_o")
        ft_rd_n_o = platform.request("ft_rd_n_o")
        ft_siwua_n_o = platform.request("ft_siwua_n_o")
        ft_data_io = platform.request("ft_data_io")
        adc_d_i = platform.request("adc_d_i")
        adc_oe_o = platform.request("adc_oe_o")
        adc_shdn_o = platform.request("adc_shdn_o")
        ext1 = platform.request("ext1")
        pa_en_n_o = platform.request("pa_en_n_o")
        mix_en_n_o = platform.request("mix_en_n_o")

        # signals
        clk80 = Signal()
        pll_fb = Signal()
        chan_a = Signal(self.ADC_WIDTH)
        chan_b = Signal(self.ADC_WIDTH)
        lsb = Signal()
        lock = Signal(RAW_STATE)
        sample_ctr = Signal(range(self.DECIMATE * self.FFT_LEN))
        sample_ctr_max = Const(self.DECIMATE * self.FFT_LEN - 1)
        cons_done = Signal()
        cons_done_clk80_dom = Signal()
        send_start = Signal()
        send_stop = Signal()
        wait_prod = Signal()
        lock_ftclk_dom = Signal()
        lock_ftclk_dom_last = Signal()

        # clock domains
        clk40_neg = ClockDomain("clk40_neg", clk_edge="neg")
        m.domains.clk40_neg = clk40_neg
        m.d.comb += ClockSignal("clk40_neg").eq(ClockSignal("sync"))

        m.domains += ClockDomain("clk60")
        m.d.comb += ClockSignal("clk60").eq(ft_clkout_i.i)
        m.domains += ClockDomain("clk80")
        m.d.comb += ClockSignal("clk80").eq(clk80)

        # ======================== submodules ========================
        # PLL
        m.submodules += Instance(
            "PLLE2_BASE",
            ("p", "CLKFBOUT_MULT", 24),
            ("p", "DIVCLK_DIVIDE", 1),
            ("p", "CLKOUT0_DIVIDE", 12),
            ("p", "CLKIN1_PERIOD", 25),
            ("o", "CLKOUT0", clk80),
            ("i", "CLKIN1", ClockSignal("sync")),
            ("i", "RST", 0),
            ("o", "CLKFBOUT", pll_fb),
            ("i", "CLKFBIN", pll_fb),
        )

        # ADC
        m.submodules.ltc2292 = ltc2292 = LTC2292(
            posedge_domain="sync", negedge_domain="clk40_neg"
        )
        m.d.comb += [
            ltc2292.di.eq(adc_d_i.i),
            chan_a.eq(ltc2292.dao),
            chan_b.eq(ltc2292.dbo),
        ]

        # FIFO
        m.submodules.fifo = fifo = AsyncFIFO(
            width=self.USB_WIDTH,
            depth=self.DECIMATE * self.FFT_LEN * 2,
            r_domain="clk60",
            w_domain="clk80",
        )
        with m.If(lsb):
            m.d.comb += fifo.w_data.eq(chan_a[: self.USB_WIDTH])
        with m.Else():
            m.d.comb += fifo.w_data.eq(
                Cat(
                    chan_a[self.USB_WIDTH :],
                    Const(0, 2 * self.USB_WIDTH - self.ADC_WIDTH),
                )
            )

        # consumption done sync
        m.submodules.cons_done_sync = cons_done_sync = FFSynchronizer(
            i=cons_done, o=cons_done_clk80_dom, o_domain="clk80"
        )

        # lock synch
        m.submodules.lock_sync = lock_sync = FFSynchronizer(
            i=lock, o=lock_ftclk_dom, o_domain="clk60"
        )

        # =========================== logic ==========================
        m.d.comb += [
            pa_en_n_o.o.eq(1),
            mix_en_n_o.o.eq(1),
            adc_oe_o.o.eq(0b01),
            adc_shdn_o.o.eq(0b00),
            ext1.o[0].eq(0b0),
            ext1.o[3].eq(lock),
            ext1.o[1].eq(0b0),
            ext1.o[4].eq(fifo.r_en),
            ext1.o[2].eq(0b0),
            ext1.o[5].eq(fifo.w_en),
        ]

        # write clock domain
        with m.If(lock == RAW_STATE.PROD):
            with m.If(sample_ctr == sample_ctr_max):
                m.d.clk80 += [
                    lock.eq(RAW_STATE.CONS),
                    sample_ctr.eq(0),
                    lsb.eq(0),
                ]
            with m.Else():
                with m.If(lsb):
                    m.d.clk80 += sample_ctr.eq(sample_ctr + 1)
                m.d.clk80 += lsb.eq(~lsb)
        with m.Else():
            with m.If(cons_done_clk80_dom):
                m.d.clk80 += [
                    lock.eq(RAW_STATE.PROD),
                    sample_ctr.eq(0),
                    lsb.eq(0),
                ]

        with m.Switch(lock):
            with m.Case(RAW_STATE.PROD):
                m.d.comb += fifo.w_en.eq(1)
            with m.Case(RAW_STATE.CONS):
                m.d.comb += fifo.w_en.eq(0)

        # read clock domain
        m.d.clk60 += lock_ftclk_dom_last.eq(lock_ftclk_dom)
        with m.If(lock_ftclk_dom == RAW_STATE.CONS & ~wait_prod):
            with m.If(~fifo.r_rdy):
                m.d.clk60 += wait_prod.eq(1)
        with m.Elif(lock_ftclk_dom == RAW_STATE.CONS):
            m.d.clk60 += wait_prod.eq(1)
        with m.Else():
            m.d.clk60 += wait_prod.eq(0)

        m.d.comb += [
            ft_oe_n_o.o.eq(1),
            ft_rd_n_o.o.eq(1),
            ft_siwua_n_o.o.eq(1),
        ]
        with m.Switch(lock_ftclk_dom):
            with m.Case(RAW_STATE.PROD):
                m.d.comb += [
                    send_start.eq(0),
                    send_stop.eq(0),
                    ft_data_io.o.eq(0),
                    ft_wr_n_o.o.eq(1),
                    fifo.r_en.eq(0),
                ]
            with m.Case(RAW_STATE.CONS):
                with m.If(lock_ftclk_dom_last == RAW_STATE.PROD):
                    m.d.comb += send_start.eq(1)
                with m.Else():
                    m.d.comb += send_start.eq(0)

                with m.If(~fifo.r_rdy):
                    m.d.comb += [send_stop.eq(1), cons_done.eq(1)]
                with m.Else():
                    m.d.comb += [send_stop.eq(0), cons_done.eq(0)]

                with m.If(send_start):
                    m.d.comb += [
                        ft_data_io.o.eq(self.START_FLAG),
                        ft_wr_n_o.o.eq(ft_txe_n_i.i),
                        fifo.r_en.eq(1),
                    ]
                with m.Elif(send_stop):
                    m.d.comb += [
                        ft_data_io.o.eq(self.STOP_FLAG),
                        ft_wr_n_o.o.eq(ft_txe_n_i.i),
                        fifo.r_en.eq(0),
                    ]
                with m.Else():
                    with m.If(wait_prod):
                        m.d.comb += [
                            ft_data_io.o.eq(0),
                            ft_wr_n_o.o.eq(1),
                            fifo.r_en.eq(0),
                        ]
                    with m.Else():
                        m.d.comb += [
                            ft_data_io.o.eq(fifo.r_data),
                            ft_wr_n_o.o.eq(~(~ft_txe_n_i.i & fifo.r_en)),
                            fifo.r_en.eq(~ft_txe_n_i.i & fifo.r_rdy),
                        ]

        return m


if __name__ == "__main__":
    raw = Raw()

    parser = argparse.ArgumentParser()
    p_action = parser.add_subparsers(dest="action")
    p_action.add_parser("simulate")
    p_action.add_parser("generate")
    p_action.add_parser("build")

    args = parser.parse_args()
    if args.action == "simulate":
        sim = Simulator(raw)
        sim.add_clock(25e-9, domain="sync")
        sim.add_clock(25e-9, domain="clk40_neg")
        sim.add_clock(16.67e-9, domain="clk60")
        with sim.write_vcd("raw.vcd", "raw.gtkw"):
            sim.run()

    if args.action == "build":
        os.environ[
            "NMIGEN_add_constraints"
        ] = "set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets pin_ft_clkout_i_0/clk60_clk]"
        platform = FMCWRadar()
        platform.build(raw, do_program=True)
