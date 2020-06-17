#!/usr/bin/env python

from skidl.pyspice import (
    lib_search_paths,
    Part,
    generate_netlist,
    SPICE,
    gnd,
    node,
    no_files,
)
import numpy as np
import os

no_files()

spicelib = os.getenv("SPICELIB")

fname = ".data/adc-filter.dat"
lib_search_paths[SPICE].append(spicelib)

vac = Part("pyspice", "SINEV", amplitude=1)
rt = Part("pyspice", "R", value=49.9)
rb = Part("pyspice", "R", value=49.9)
c = Part("pyspice", "C", value=100e-12)
rload = Part("pyspice", "R", value=1e6)

vac["p"] += rt["p"]
vac["n"] += rb["p"]
rt["n"] += c["p"], rload["p"]
rb["n"] += c["n"], rload["n"], gnd

circ = generate_netlist(libs=spicelib)
sim = circ.simulator()
waveforms = sim.ac(
    variation="dec",
    number_of_points=100,
    start_frequency=1,
    stop_frequency=100e6,
)

freq = waveforms.frequency
vinp = waveforms[node(vac["p"])]
vinn = waveforms[node(vac["n"])]
voutp = waveforms[node(rload["p"])]

with open(fname, "w") as f:
    f.write("{:<12} {:<12} {:<12}\n".format("freq", "vratio", "phase"))
    for fr, vin, vout in zip(
        freq.as_ndarray(),
        vinp.as_ndarray() - vinn.as_ndarray(),
        voutp.as_ndarray(),
    ):
        arg = np.imag(vout / vin) / np.real(vout / vin)
        db = 20 * np.log10(abs(vout) / abs(vin))
        f.write(
            "{:<12.2f} {:<12.5f} {:<12.5f}\n".format(fr, db, np.arctan(arg),)
        )
