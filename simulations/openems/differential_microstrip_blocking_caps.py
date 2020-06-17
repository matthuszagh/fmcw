#!/usr/bin/env python

import numpy as np
from pyems.simulation import Simulation
from pyems.pcb import common_pcbs
from pyems.structure import (
    DifferentialMicrostrip,
    PCB,
    common_smd_passives,
    SMDPassive,
)
from pyems.coordinate import Coordinate2, Axis, Box3, Coordinate3, Box2
from pyems.utilities import print_table, mil_to_mm
from pyems.field_dump import FieldDump, DumpType
from pyems.mesh import Mesh

freq = np.arange(0, 18e9, 10e6)
unit = 1e-3
ref_freq = 5.6e9
sim = Simulation(freq=freq, unit=unit, reference_frequency=ref_freq)

pcb_len = 30
pcb_width = 10

trace_width = 0.85
trace_gap = mil_to_mm(6)

pcb_prop = common_pcbs["oshpark4"]
pcb = PCB(
    sim=sim,
    pcb_prop=pcb_prop,
    length=pcb_len,
    width=pcb_width,
    layers=range(3),
    omit_copper=[0],
)

cap_dim = common_smd_passives["0201C"]
cap_dim.set_unit(unit)
pad_width = trace_width
pad_length = cap_dim.width

SMDPassive(
    pcb=pcb,
    position=Coordinate2(0, trace_gap / 2 + trace_width / 2),
    axis=Axis("x"),
    dimensions=cap_dim,
    pad_width=pad_width,
    pad_length=pad_length,
    c=10e-12,
)
SMDPassive(
    pcb=pcb,
    position=Coordinate2(0, -trace_gap / 2 - trace_width / 2),
    axis=Axis("x"),
    dimensions=cap_dim,
    pad_width=pad_width,
    pad_length=pad_length,
    c=10e-12,
)

box = Box2(
    Coordinate2(-pcb_len / 2, 0),
    Coordinate2(-cap_dim.length / 2 - pad_length / 2, 0),
)
DifferentialMicrostrip(
    pcb=pcb,
    position=box.center(),
    length=box.length(),
    width=trace_width,
    gap=trace_gap,
    propagation_axis=Axis("x"),
    port_number=1,
    excite=True,
    ref_impedance=50,
)
box = Box2(
    Coordinate2(cap_dim.length / 2 + pad_length / 2, 0),
    Coordinate2(pcb_len / 2, 0),
)
DifferentialMicrostrip(
    pcb=pcb,
    position=box.center(),
    length=box.length(),
    width=trace_width,
    gap=trace_gap,
    propagation_axis=Axis("x", direction=-1),
    port_number=2,
    ref_impedance=50,
)

Mesh(
    sim=sim,
    metal_res=1 / 80,
    nonmetal_res=1 / 10,
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
    data=[sim.freq / 1e9, sim.s_param(1, 1), sim.s_param(2, 1)],
    col_names=["freq", "s11", "s21"],
    prec=[2, 4, 4],
)
