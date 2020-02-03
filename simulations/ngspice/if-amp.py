#!/usr/bin/env python

from skidl.pyspice import (
    lib_search_paths,
    Part,
    generate_netlist,
    SPICE,
    gnd,
    node,
)
import numpy as np
import os

spicelib = os.getenv("SPICELIB")


fname = "data/if-amp-spice.dat"
lib_search_paths[SPICE].append(spicelib)

rcm_val = 50e6
v5 = Part("pyspice", "V", value=5)
v33 = Part("pyspice", "V", value=33)
v15 = Part("pyspice", "V", value=1.5)
vs = Part("pyspice", "SINEV", amplitude=1)
# component declaration
rout = Part("pyspice", "R", value=1e9)
rload = Part("pyspice", "R", value=1e3)
lt = Part("pyspice", "L", value=2.2e-6)
lb = Part("pyspice", "L", value=2.2e-6)
cm = Part("pyspice", "C", value=2.2e-9)
ct = Part("pyspice", "C", value=10e-9)
cb = Part("pyspice", "C", value=10e-9)
rfbt = Part("pyspice", "R", value=8.2e3)
cfbt = Part("pyspice", "C", value=10e-12)
rfbb = Part("pyspice", "R", value=8.2e3)
cfbb = Part("pyspice", "C", value=10e-12)
ada4940 = Part("ADA4940", "ada4940")
rgt = Part("pyspice", "R", value=549)
rgb = Part("pyspice", "R", value=549)

shunt_top = Part("pyspice", "R", value=50)
shunt_bot = Part("pyspice", "R", value=50)
cbp_top = Part("pyspice", "C", value=100e-9)
cbp_bot = Part("pyspice", "C", value=100e-9)

# component connections
gnd += v33[2], v5[2], cbp_top[2], cbp_bot[2], v15[2]
vs[1] += shunt_top[2], lt[1], rout[1]
vs[2] += shunt_bot[2], lb[1], rout[2]
v5[1] += shunt_top[1], shunt_bot[1], cbp_top[1], cbp_bot[1]
v15[1] += ada4940["110"]
lt[2] += cm[1], ct[1]
lb[2] += cm[2], cb[1]
ct[2] += rgt[1]
cb[2] += rgb[1]
rgt[2] += rfbt[1], cfbt[1], ada4940["3A"]
rgb[2] += rfbb[1], cfbb[1], ada4940["9"]
ada4940["3B"] += rfbt[2], cfbt[2]
ada4940["9B"] += rfbb[2], cfbb[2]
ada4940["71B"] += rload[1]
ada4940["71"] += rload[2]
ada4940["99"] += v33[1]
ada4940["50"] += v33[2]

# generate netlist and waveforms
circ = generate_netlist(libs=spicelib)
sim = circ.simulator()
waveforms = sim.ac(
    variation="dec",
    number_of_points=100,
    start_frequency=1,
    stop_frequency=10e6,
)

freq = waveforms.frequency
vinp = waveforms[node(vs[1])]
vinn = waveforms[node(vs[2])]
voutp = waveforms[node(rload[1])]
voutn = waveforms[node(rload[2])]

with open(fname, "w") as f:
    f.write("{:<12} {:<12} {:<12}\n".format("freq", "vratio", "phase"))
    for fr, vin, vout in zip(
        freq.as_ndarray(),
        vinp.as_ndarray() - vinn.as_ndarray(),
        voutp.as_ndarray() - voutn.as_ndarray(),
    ):
        arg = np.imag(vout / vin) / np.real(vout / vin)
        db = 20 * np.log10(abs(vout) / abs(vin))
        f.write(
            "{:<12.2f} {:<12.5f} {:<12.5f}\n".format(fr, db, np.arctan(arg),)
        )
