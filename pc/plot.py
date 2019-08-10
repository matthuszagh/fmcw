#!/usr/bin/python

import usb.core
import usb.util
import pylibftdi as ftdi


def access_bit(data, num):
    base = int(num/8)
    shift = num % 8
    return (data[base] & (1 << shift)) >> shift


SYNCFF = 0x40  # Configures bit-bang mode for synchronous FIFO.
SIO_RTS_CTS_HS = (0x1 << 8)
device = ftdi.Device(mode='b', interface_select=ftdi.INTERFACE_A)
device.open()
device.ftdi_fn.ftdi_set_bitmode(0xff, SYNCFF)
device.ftdi_fn.ftdi_read_data_set_chunksize(0x10000)
device.ftdi_fn.ftdi_write_data_set_chunksize(0x10000)
device.ftdi_fn.ftdi_setflowctrl(SIO_RTS_CTS_HS)
device.flush()
dev = usb.core.find(idVendor=0x0403, idProduct=0x6010)
if dev is None:
    raise ValueError('Device not found')

if dev.is_kernel_driver_active(0):
    try:
        dev.detach_kernel_driver(0)
        print("driver detached")
    except usb.core.USBError as e:
        sys.exit("Could not detach kernel driver.")

else:
    print("No kernel driver attached.")

dev.set_configuration()
endpoint = dev[0][(0, 0)][0]

try:
    usb.util.claim_interface(dev, 0)
    print("Claimed device.")
except:
    sys.exit("Could not claim device.")

data = None
while True:
    try:
        data = dev.read(endpoint.bEndpointAddress,
                        endpoint.wMaxPacketSize)
        print(data)
        # list_data = [access_bit(data, i) for i in range(len(data)*8)]
        # str_data = ''.join(str(e) for e in list_data)
        # print(str_data)

    except usb.core.USBError as e:
        data = None
        if e.args == ('Operation timed out',):
            continue
