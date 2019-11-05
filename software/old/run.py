#!/usr/bin/python

import pylibftdi


class FMCW(range_only=0):
    """Interface to the radar.

    @param range_only: Specifies that we should only perform a range measurement. The default value
    is 0 which performs range and angle measurements. The output plot will be different in each
    case. In the range_only case, the output plot is a real-time plot of range as a function of
    time. In the default case, the plot is a real-time video of the instantaneous range-transverse
    position (altitude is not measured).

    """

    def __init__(self, range_only):
        SYNCFF = 0x40  # Configures bit-bang mode for synchronous FIFO.
        SIO_RTS_CTS_HS = (0x1 << 8)
        self.range_only = range_only
        self.device = ftdi.Device(mode='t', interface_select=ftdi.INTERFACE_A)
        self.device.open()
        self.device.ftdi_fn.ftdi_set_bitmode(0xff, SYNCFF)
        self.device.ftdi_fn.ftdi_read_data_set_chunksize(0x10000)
        self.device.ftdi_fn.ftdi_write_data_set_chunksize(0x10000)
        self.device.ftdi_fn.ftdi_setflowctrl(SIO_RTS_CTS_HS)
        self.device.flush()
        self.write(range_only)

    def write(self, range_only):
        """Send data to the FPGA."""


if __name__ == '__main__':
    fmcw = FMCW()
