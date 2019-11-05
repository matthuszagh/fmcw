#!/usr/bin/env python

import pylibftdi as ftdi

SYNCFF = 0x40
SIO_RTS_CTS_HS = (0x1 << 8)
with ftdi.Device(mode='t', interface_select=ftdi.INTERFACE_A) as dev:
    dev.open()
    dev.ftdi_fn.ftdi_set_bitmode(0xff, SYNCFF)
    dev.ftdi_fn.ftdi_read_data_set_chunksize(0x10000)
    dev.ftdi_fn.ftdi_write_data_set_chunksize(0x10000)
    dev.ftdi_fn.ftdi_setflowctrl(SIO_RTS_CTS_HS)
    dev.flush()

    with open("log.bin", "w") as f:
        print("Reading...")
        while True:
            rdata = dev.read(0x10000)
            f.write(rdata)
