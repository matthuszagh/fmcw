#!/usr/bin/env python

import numpy as np
from pyems.simulation import Simulation
from pyems.structure import PCB, Microstrip
from pyems.coordinate import Coordinate2, Coordinate3, Box2, Box3
from pyems.pcb import common_pcbs
from pyems.mesh import Mesh
from pyems.utilities import pretty_print, mil_to_mm
from pyems.field_dump import FieldDump

freq = np.linspace(4e9, 8e9, 501)
sim = Simulation(freq=freq, unit=1e-3)
pcb_prop = common_pcbs["oshpark4"]
pcb_len = 30
pcb_width = 10
trace_width = 0.34
gap = mil_to_mm(6)
via_gap = 0.4

pcb = PCB(sim=sim, pcb_prop=pcb_prop, length=30, width=10, layers=range(3))
micro = Microstrip(
    pcb=pcb,
    box=Box2(
        Coordinate2(-pcb_len / 2, -trace_width / 2),
        Coordinate2(pcb_len / 2, trace_width / 2),
    ),
    trace_layer=0,
    gnd_layer=1,
    gnd_gap=gap,
    via_gap=via_gap,
    via=None,
    via_spacing=1.27,
    port_number=1,
    excite=True,
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
    metal_res=1 / 80,
    nonmetal_res=1 / 40,
    smooth=(1.1, 1.5, 1.5),
    min_lines=25,
    expand_bounds=((0, 0), (8, 8), (8, 8)),
)

sim.run()
sim.view_field()

pretty_print(
    data=[sim.freq / 1e9, np.abs(sim.ports[0].impedance()), sim.s_param(1, 1)],
    col_names=["freq", "z0", "s11"],
    prec=[4, 4, 4],
)
