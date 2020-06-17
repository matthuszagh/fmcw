#!/usr/bin/env python
"""
Test the effect of different linear taper angles/lengths on S11 and S21.
"""

import numpy as np
from pyems.pcb import common_pcbs
from pyems.simulation import Simulation
from pyems.utilities import print_table
from pyems.structure import PCB, Microstrip
from pyems.coordinate import Box2, Coordinate2, Axis, Coordinate3, Box3
from pyems.mesh import Mesh
from pyems.field_dump import FieldDump, DumpType

unit = 1e-3
ref_freq = 5.6e9
freq_res = 1e7
freq = np.arange(0, 18e9 + freq_res, freq_res)
pcb_prop = common_pcbs["oshpark4"]
pcb_len = 10
pcb_width = 5
trace_width = 0.38
z0_ref = 50

microstrip_discontinuity_width = 0.5
microstrip_discontinuity_length = 1

sim = Simulation(freq=freq, unit=unit, reference_frequency=5.6e9)
pcb = PCB(
    sim=sim,
    pcb_prop=pcb_prop,
    length=pcb_len,
    width=pcb_width,
    layers=range(3),
    omit_copper=[0],
)

Microstrip(
    pcb=pcb,
    position=Coordinate2(0, 0),
    length=microstrip_discontinuity_length,
    width=microstrip_discontinuity_width,
    propagation_axis=Axis("x"),
    trace_layer=0,
    gnd_layer=1,
)

box = Box2(
    Coordinate2(-pcb_len / 2, -trace_width / 2),
    Coordinate2(-microstrip_discontinuity_length / 2, trace_width / 2),
)
Microstrip(
    pcb=pcb,
    position=box.center(),
    length=box.length(),
    width=trace_width,
    propagation_axis=Axis("x"),
    trace_layer=0,
    gnd_layer=1,
    port_number=1,
    excite=True,
    feed_shift=0.35,
    ref_impedance=50,
)

box = Box2(
    Coordinate2(microstrip_discontinuity_length / 2, -trace_width / 2),
    Coordinate2(pcb_len / 2, trace_width / 2),
)
Microstrip(
    pcb=pcb,
    position=box.center(),
    length=box.length(),
    width=trace_width,
    propagation_axis=Axis("x", direction=-1),
    trace_layer=0,
    gnd_layer=1,
    port_number=2,
    ref_impedance=50,
)

Mesh(
    sim=sim,
    metal_res=1 / 120,
    nonmetal_res=1 / 40,
    min_lines=5,
    expand_bounds=((0, 0), (0, 0), (10, 40)),
)

FieldDump(
    sim=sim,
    box=Box3(
        Coordinate3(-pcb_len / 2, -pcb_width / 2, 0),
        Coordinate3(pcb_len / 2, pcb_width / 2, 0),
    ),
    dump_type=DumpType.current_density_time,
)

sim.run()
sim.view_field()

print_table(
    data=[freq / 1e9, sim.s_param(1, 1)],
    col_names=["freq", "s11"],
    prec=[2, 4],
)
