#!/usr/bin/env python
import sys
import numpy as np

RAW_LEN = 20480

if __name__ == "__main__":
    with sys.stdin.buffer as buf:
        while True:
            for i in range(RAW_LEN):
                val = int.from_bytes(
                    buf.read(2), byteorder=sys.byteorder, signed=True
                )
                print("{}: {} ({:x})".format(i, val, val))
            #     print(val)
            # print("")
