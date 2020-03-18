#!/usr/bin/env python

import numpy as np
from pyems.simulation import Simulation
from pyems.structure import PCB, Microstrip
from pyems.coordinate import Coordinate2, Coordinate3, Box3
from pyems.pcb import common_pcbs
from pyems.mesh import Mesh
from pyems.utilities import pretty_print, mil_to_mm
from pyems.field_dump import FieldDump
from CSXCAD.CSTransform import CSTransform

freq = np.linspace(4e9, 8e9, 501)
sim = Simulation(freq=freq, unit=1e-3)
pcb_prop = common_pcbs["oshpark4"]
pcb_len = 30
pcb_width = 20
trace_width = 0.34
gap = mil_to_mm(6)
via_gap = 0.4
micro_len = 10

pcb = PCB(
    sim=sim,
    pcb_prop=pcb_prop,
    length=pcb_len,
    width=pcb_width,
    layers=range(3),
)
Microstrip(
    pcb=pcb,
    position=Coordinate2(
        -pcb_len / 4 + (trace_width / 4), micro_len / 2 - (trace_width / 2)
    ),
    length=pcb_len / 2 + (trace_width / 2),
    width=trace_width,
    negative_direction=False,
    trace_layer=0,
    gnd_layer=1,
    gnd_gap=gap,
    via_gap=via_gap,
    via=None,
    shorten_via_wall=(0, trace_width + gap + via_gap),
    port_number=1,
    feed_shift=0.4,
    excite=True,
)

rotate = CSTransform()
rotate.AddTransform("RotateAxis", "z", -90)
Microstrip(
    pcb=pcb,
    position=Coordinate2(0, 0),
    length=micro_len,
    width=trace_width,
    trace_layer=0,
    gnd_layer=1,
    gnd_gap=gap,
    terminal_gaps=True,
    via_gap=via_gap,
    via=None,
    shorten_via_wall=(
        trace_width + gap + via_gap,
        trace_width + gap + via_gap,
    ),
    transform=rotate,
)

Microstrip(
    pcb=pcb,
    position=Coordinate2(
        pcb_len / 4 - (trace_width / 4), -micro_len / 2 + (trace_width / 2)
    ),
    length=pcb_len / 2 + (trace_width / 2),
    width=trace_width,
    negative_direction=True,
    trace_layer=0,
    gnd_layer=1,
    gnd_gap=gap,
    via_gap=via_gap,
    via=None,
    shorten_via_wall=(trace_width + gap + via_gap, 0),
    port_number=2,
    excite=False,
)

dump = FieldDump(
    sim=sim,
    box=Box3(
        Coordinate3(-pcb_len / 2, -pcb_width / 2, 0),
        Coordinate3(pcb_len / 2, pcb_width / 2, 0),
    ),
)

mesh = Mesh(
    sim=sim,
    metal_res=1 / 120,
    nonmetal_res=1 / 40,
    smooth=(1.5, 1.5, 1.5),
    min_lines=5,
    expand_bounds=((0, 0), (8, 8), (8, 8)),
)

sim.run()
sim.view_field()

pretty_print(
    data=[sim.freq / 1e9, sim.s_param(1, 1), sim.s_param(2, 1)],
    col_names=["freq", "s11", "s21"],
    prec=[4, 4, 4],
)
