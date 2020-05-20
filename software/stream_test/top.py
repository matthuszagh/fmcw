#!/usr/bin/env python

import os
from nmigen.vendor.xilinx_7series import Xilinx7SeriesPlatform
from nmigen.build import Resource, Pins, Clock, Attrs, Subsignal
from nmigen import Module, Elaboratable, Signal, ClockDomain, ClockSignal
from nmigen.lib.fifo import AsyncFIFO


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
    ]

    connectors = []

    default_clk = "clk40"

    def toolchain_program(self, products, name):
        # bitstream = products.get("{}.bin".format(name))
        os.system("openocd -f interface.cfg -f program_fpga.cfg")


class Stream(Elaboratable):
    """
    """

    def elaborate(self, platform):
        m = Module()

        # pins
        ft_clkout_i = platform.request("ft_clkout_i")
        ft_wr_n_o = platform.request("ft_wr_n_o")
        ft_wr_n_o.o.reset = 1
        ft_txe_n_i = platform.request("ft_txe_n_i")
        ft_suspend_n_i = platform.request("ft_suspend_n_i")
        ft_oe_n_o = platform.request("ft_oe_n_o")
        ft_rd_n_o = platform.request("ft_rd_n_o")
        ft_siwua_n_o = platform.request("ft_siwua_n_o")
        ft_data_io = platform.request("ft_data_io")
        ext1 = platform.request("ext1")
        pa_en_n_o = platform.request("pa_en_n_o")

        # clock domains
        m.domains += ClockDomain("clk60")
        m.d.comb += ClockSignal("clk60").eq(ft_clkout_i.i)

        # signals
        ctr = Signal(8, reset=0)
        ctr_last = Signal(8, reset=0)
        ft_txe_last = Signal(1, reset=0)

        # sync + comb logic
        with m.If(~ft_txe_n_i.i & ft_suspend_n_i.i):
            m.d.clk60 += [ft_wr_n_o.o.eq(0), ctr.eq(ctr + 1), ctr_last.eq(ctr)]
        with m.Elif(ft_txe_n_i.i & ~ft_txe_last):
            m.d.clk60 += [ctr.eq(ctr_last), ft_wr_n_o.o.eq(1)]
        with m.Else():
            m.d.clk60 += [ft_wr_n_o.o.eq(1)]

        m.d.clk60 += [ft_txe_last.eq(ft_txe_n_i.i)]

        m.d.comb += [
            ft_oe_n_o.o.eq(1),
            ft_rd_n_o.o.eq(1),
            ft_siwua_n_o.o.eq(1),
            ft_data_io.o.eq(ctr),
            ft_data_io.oe.eq(1),
            pa_en_n_o.o.eq(1),
        ]

        return m


class StreamCDC(Elaboratable):
    """
    """

    def elaborate(self, platform):
        m = Module()

        # pins
        ft_clkout_i = platform.request("ft_clkout_i")
        ft_wr_n_o = platform.request("ft_wr_n_o")
        ft_wr_n_o.o.reset = 1
        ft_txe_n_i = platform.request("ft_txe_n_i")
        ft_suspend_n_i = platform.request("ft_suspend_n_i")
        ft_oe_n_o = platform.request("ft_oe_n_o")
        ft_rd_n_o = platform.request("ft_rd_n_o")
        ft_siwua_n_o = platform.request("ft_siwua_n_o")
        ft_data_io = platform.request("ft_data_io")
        ext1 = platform.request("ext1")
        pa_en_n_o = platform.request("pa_en_n_o")

        # clock domains
        m.domains += ClockDomain("clk60")
        m.d.comb += ClockSignal("clk60").eq(ft_clkout_i.i)

        # signals
        ctr = Signal(8, reset=0)
        ctr_last = Signal(8, reset=0)
        ft_txe_last = Signal(1, reset=0)

        # submodules
        m.submodules.fifo = fifo = AsyncFIFO(
            width=8, depth=1024, r_domain="clk60", w_domain="sync"
        )

        # logic
        m.d.comb += [
            ft_oe_n_o.o.eq(1),
            ft_rd_n_o.o.eq(1),
            ft_siwua_n_o.o.eq(1),
            ft_data_io.oe.eq(1),
            pa_en_n_o.o.eq(1),
        ]

        m.d.comb += [
            ft_data_io.o.eq(fifo.r_data),
            fifo.w_data.eq(ctr),
        ]

        with m.If(fifo.w_rdy):
            m.d.sync += [fifo.w_en.eq(1), ctr.eq(ctr + 1)]
        with m.Else():
            m.d.sync += fifo.w_en.eq(0)

        with m.If(~ft_txe_n_i & ft_suspend_n_i & fifo.r_rdy):
            m.d.clk60 += [ft_wr_n_o.o.eq(0), fifo.r_en.eq(1)]
        with m.Else():
            m.d.clk60 += [ft_wr_n_o.o.eq(1), fifo.r_en.eq(0)]

        return m


class FT245(Elaboratable):
    """
    """

    def elaborate(self, platform):
        """
        """


if __name__ == "__main__":
    os.environ[
        "NMIGEN_add_constraints"
    ] = "set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets pin_ft_clkout_i_0/clk60_clk]"
    platform = FMCWRadar()
    platform.build(StreamCDC(), do_program=True)
