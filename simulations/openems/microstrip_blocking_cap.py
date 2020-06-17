#!/usr/bin/env python

import numpy as np
from pyems.pcb import common_pcbs
from pyems.simulation import Simulation
from pyems.field_dump import FieldDump, DumpType
from pyems.utilities import print_table, mil_to_mm
from pyems.structure import (
    PCB,
    Microstrip,
    common_smd_passives,
    SMDPassive,
)
from pyems.coordinate import Box2, Box3, Coordinate2, Coordinate3, Axis
from pyems.mesh import Mesh

unit = 1e-3
freq = np.arange(5e7, 18e9, 1e7)
sim = Simulation(freq=freq, unit=unit)
pcb_prop = common_pcbs["oshpark4"]
pcb_len = 10
pcb_width = 5
trace_width = 0.38
gap = mil_to_mm(6)
via_gap = 0.4
z0_ref = 50

# 0402 cap
# cap_dim = common_smd_passives["0402C"]
# cap_dim.set_unit(unit)
# pad_width = cap_dim.width
# pad_length = pad_width
# # taper_length = pad_width / 2
# taper_length = 0

# 0201 cap
cap_dim = common_smd_passives["0201C"]
cap_dim.set_unit(unit)
pad_width = cap_dim.width
pad_length = cap_dim.width
# taper_length = pad_length / 4
taper_length = 0
# taper_length = 0.1501806


pcb = PCB(
    sim=sim,
    pcb_prop=pcb_prop,
    length=pcb_len,
    width=pcb_width,
    layers=range(3),
    omit_copper=[0],
)

box = Box2(
    Coordinate2(-pcb_len / 2, -trace_width / 2),
    Coordinate2(
        -(cap_dim.length / 2) - (pad_length / 2) - taper_length,
        trace_width / 2,
    ),
)
Microstrip(
    pcb=pcb,
    position=box.center(),
    length=box.length(),
    width=box.width(),
    propagation_axis=Axis("x"),
    trace_layer=0,
    gnd_layer=1,
    port_number=1,
    excite=True,
    feed_shift=0.35,
    ref_impedance=50,
)

SMDPassive(
    pcb=pcb,
    position=Coordinate2(0, 0),
    axis=Axis("x"),
    dimensions=cap_dim,
    pad_width=pad_width,
    pad_length=pad_length,
    c=10e-12,
    pcb_layer=0,
    gnd_cutout_width=4.44981217,
    gnd_cutout_length=1,
    # gnd_cutout_width=1.2,
)

box = Box2(
    Coordinate2(pcb_len / 2, trace_width / 2),
    Coordinate2(
        (cap_dim.length / 2) + (pad_length / 2) + taper_length,
        -trace_width / 2,
    ),
)
Microstrip(
    pcb=pcb,
    position=box.center(),
    length=box.length(),
    width=box.width(),
    propagation_axis=Axis("x", direction=-1),
    trace_layer=0,
    gnd_layer=1,
    port_number=2,
    excite=False,
    ref_impedance=50,
)

FieldDump(
    sim=sim,
    box=Box3(
        Coordinate3(-pcb_len / 2, -pcb_width / 2, 0),
        Coordinate3(pcb_len / 2, pcb_width / 2, 0),
    ),
    dump_type=DumpType.current_density_time,
)

Mesh(
    sim=sim,
    metal_res=1 / 120,
    nonmetal_res=1 / 40,
    smooth=(1.2, 1.2, 1.2),
    min_lines=5,
    expand_bounds=((0, 0), (0, 0), (10, 20)),
)

sim.run()
sim.view_field()

print_table(
    data=[sim.freq / 1e9, sim.s_param(1, 1), sim.s_param(2, 1)],
    col_names=["freq", "s11", "s21"],
    prec=[4, 4, 4],
)
