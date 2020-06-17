#!/usr/bin/env python
"""
Unit tests for async_fifo.v
"""

import random
from typing import List
from collections import deque

from cocotb_helpers import Clock, MultiClock

import cocotb
from cocotb.result import TestFailure
from cocotb.triggers import *
from cocotb.binary import *


class AsyncFifoTB:
    """
    Async FIFO testbench class. Used to setup, drive and monitor the
    async FIFO under test.
    """

    def __init__(self, dut, read_freq: float = 60, write_freq: float = 40):
        rdclk = Clock(dut.rdclk, read_freq)
        wrclk = Clock(dut.wrclk, write_freq)
        self.multiclock = MultiClock([rdclk, wrclk])
        self.dut = dut

    @cocotb.coroutine
    async def setup(self):
        """Startup the async FIFO."""
        self.multiclock.start_all_clocks()
        await self.reset()

    @cocotb.coroutine
    async def reset(self):
        """
        Perform a sufficiently long reset to be registered by all clock
        domains.
        """
        await self.await_all_clocks()
        self.dut.rst_n <= 0
        self.dut.rden <= 0
        self.dut.wren <= 0
        await self.await_all_clocks()
        self.dut.rst_n <= 1

    @cocotb.coroutine
    async def await_all_clocks(self):
        """
        Wait for positive edge on both clocks before proceeding.
        """
        trigs = []
        for clk in self.multiclock.clocks:
            trigs.append(RisingEdge(clk.clk))

        await Combine(*trigs)

    @cocotb.coroutine
    async def write(self, val):
        """Write a value to the FIFO."""
        await RisingEdge(self.dut.wrclk)
        self.dut.wren <= 1
        self.dut.wrdata <= val
        await RisingEdge(self.dut.wrclk)

    @cocotb.coroutine
    async def read(self):
        """Read a value from the FIFO."""
        await RisingEdge(self.dut.rdclk)
        self.dut.rden <= 1
        await RisingEdge(self.dut.rdclk)
        await ReadOnly()
        rdval = self.dut.rddata.value
        return rdval

    @cocotb.coroutine
    async def write_continuous(self, vals: List[int]):
        """
        """
        num_vals = len(vals)
        i = 0
        while i < num_vals:
            await RisingEdge(self.dut.wrclk)
            if self.dut.full.value.integer == 0:
                self.dut.wren <= 1
                self.dut.wrdata <= vals[i]
                i += 1

    @cocotb.coroutine
    async def read_continuous(self, num_vals: int) -> List[int]:
        """
        """
        vals = []
        i = 0
        while i < num_vals:
            await RisingEdge(self.dut.rdclk)
            if self.dut.empty.value.integer == 0:
                self.dut.rden <= 1
            else:
                self.dut.rden <= 0

            if self.dut.rden.value.integer == 1:
                val = self.dut.rddata.value.integer
                vals.append(val)
                i += 1

        return vals

    @cocotb.coroutine
    async def wait_n_read_cycles(self, ncycles):
        """Wait ncycles cycles for rdclk."""
        await RisingEdge(self.dut.rdclk)
        self.dut.rden <= 0
        while ncycles > 0:
            ncycles -= 1
            await RisingEdge(self.dut.rdclk)

    @cocotb.coroutine
    async def wait_n_write_cycles(self, ncycles):
        """Wait ncycles cycles for wrclk."""
        await RisingEdge(self.dut.wrclk)
        self.dut.wren <= 0
        while ncycles > 0:
            ncycles -= 1
            await RisingEdge(self.dut.wrclk)

    @cocotb.coroutine
    async def get_value(self, obj):
        """
        Return the current value of some part of the FIFO. Note that this
        does not wait for a clock edge, so care should be taken that
        the read is performed at the desired time.

        obj: The value to read (e.g. dut.wraddr)
        """
        await ReadOnly()
        return obj.value


@cocotb.test()
async def write_and_check_addr(dut):
    """
    Write a single value to the FIFO and ensure the internal address
    increments.
    """
    fifo = AsyncFifoTB(dut)
    await fifo.setup()
    old_addr = await fifo.get_value(fifo.dut.wraddr)
    await fifo.write(0)
    new_addr = await fifo.get_value(fifo.dut.wraddr)
    if new_addr.integer != old_addr.integer + 1:
        raise TestFailure(
            (
                "Write failed to increment internal FIFO address (wraddr)."
                " Actual: %d, expected: %d."
            )
            % (dut.wraddr.value.integer, old_addr.integer + 1)
        )


@cocotb.test()
async def write_single_val_immediate_read(dut):
    """
    Write a single value to the FIFO, immediately read and check the
    values match.
    """
    fifo = AsyncFifoTB(dut)
    await fifo.setup()
    wrval = random.randint(0, 2 ** 64 - 1)
    await fifo.write(wrval)
    rdval = await fifo.read()
    if wrval != rdval.integer:
        raise TestFailure(
            ("Write value differs from read value." " Write: %d, read: %d.")
            % (wrval, rdval.integer)
        )


@cocotb.test()
async def write_single_val_delay_read(dut):
    """
    Write a single value to the FIFO, wait some number of clock cycles
    and then read and check that the values match.
    """
    fifo = AsyncFifoTB(dut)
    await fifo.setup()
    wrval = random.randint(0, 2 ** 64 - 1)
    await fifo.write(wrval)
    ncycles = random.randint(0, 100)
    await fifo.wait_n_read_cycles(ncycles)
    rdval = await fifo.read()
    if wrval != rdval.integer:
        raise TestFailure(
            ("Write value differs from read value." " Write: %d, read: %d.")
            % (wrval, rdval.integer)
        )


@cocotb.test()
async def write_sequence_continuous_immediate_read_sequence_continuous(dut):
    """
    Write an uninterrupted sequence of values to the FIFO, then
    immediately read them (also uninterrupted) and check that the
    values match.
    """
    fifo = AsyncFifoTB(dut)
    await fifo.setup()
    num_items = 500
    wrvals = [random.randint(0, 2 ** 64 - 1) for n in range(num_items)]
    for i, _ in enumerate(wrvals):
        await fifo.write(wrvals[i])

    for i in range(num_items):
        rdval = await fifo.read()
        if wrvals[i] != rdval.integer:
            raise TestFailure(
                (
                    "Sequence item %d: Write value differs from read value."
                    " Write: %d, read: %d."
                )
                % (i, wrvals[i], rdval.integer)
            )


@cocotb.test()
async def write_sequence_continuous_delay_read_sequence_continuous(dut):
    """
    Write an uninterrupted sequence of values to the FIFO, delay some
    number of read clock cycles then read them (also uninterrupted)
    and check that the values match.
    """
    fifo = AsyncFifoTB(dut)
    await fifo.setup()
    num_items = 500
    wrvals = [random.randint(0, 2 ** 64 - 1) for n in range(num_items)]
    for i, _ in enumerate(wrvals):
        await fifo.write(wrvals[i])

    ncycles = random.randint(0, 100)
    await fifo.wait_n_read_cycles(ncycles)

    for i in range(num_items):
        rdval = await fifo.read()
        if wrvals[i] != rdval.integer:
            raise TestFailure(
                (
                    "Sequence item %d: Write value differs from read value."
                    " Write: %d, read: %d."
                )
                % (i, wrvals[i], rdval.integer)
            )


@cocotb.test()
async def write_sequence_broken_delay_read_sequence_continuous(dut):
    """
    Write a sequence of values (interspersed with non-writes) to the
    FIFO, delay some number of read clock cycles then read them
    (uninterrupted) and check that the values match.
    """
    fifo = AsyncFifoTB(dut)
    await fifo.setup()
    num_items = 500
    wrvals = [random.randint(0, 2 ** 64 - 1) for n in range(num_items)]
    interrupt = 1
    i = 0
    while i < len(wrvals):
        if i % 10 == 0:
            if interrupt:
                await fifo.wait_n_write_cycles(1)
                interrupt = 0
                continue
            else:
                interrupt = 1

        await fifo.write(wrvals[i])
        i += 1

    ncycles = random.randint(0, 100)
    await fifo.wait_n_read_cycles(ncycles)

    for i in range(num_items):
        rdval = await fifo.read()
        if wrvals[i] != rdval.integer:
            raise TestFailure(
                (
                    "Sequence item %d: Write value differs from read value."
                    " Write: %d, read: %d."
                )
                % (i, wrvals[i], rdval.integer)
            )


@cocotb.test()
async def write_read_simultaneous(dut):
    """
    Simultaneously write to and read from the FIFO. Ensure data
    validity.
    """
    fifo = AsyncFifoTB(dut)
    await fifo.setup()
    depth = 2000
    queue = deque([])
    while depth > 0:
        depth -= 1
        wrval = random.randint(0, 2 ** 64 - 1)
        await ReadOnly()
        full = fifo.dut.full.value.integer
        empty = fifo.dut.empty.value.integer

        write = fifo.write(wrval)
        read = fifo.read()

        result = await First(write, read)
        # read returns a value, write doesn't
        if result is None and not full:
            queue.append(wrval)
        else:
            if result is not None and not empty:
                rdval = result
                top_queue = queue.popleft()
                if rdval.integer != top_queue:
                    raise TestFailure(
                        (
                            "Write value differs from read value."
                            " Write: %d, read: %d."
                        )
                        % (top_queue, rdval.integer)
                    )


@cocotb.test()
async def read_write_continuous(dut):
    """
    """
    fifo = AsyncFifoTB(dut)
    await fifo.setup()
    num_vals = 24000
    write_vals = [random.randint(0, 2 ** 64 - 1) for _ in range(num_vals)]
    cocotb.fork(fifo.write_continuous(vals=write_vals))
    read_vals = await fifo.read_continuous(num_vals=num_vals)
    if write_vals != read_vals:
        print(read_vals)
        raise TestFailure("Write and read values differ")
