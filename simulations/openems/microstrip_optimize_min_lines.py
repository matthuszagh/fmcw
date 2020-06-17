#!/usr/bin/env python

import numpy as np
from pyems.structure import PCB, Microstrip
from pyems.simulation import Simulation
from pyems.mesh import Mesh
from pyems.pcb import common_pcbs
from pyems.coordinate import Coordinate2, Axis
from pyems.calc import optimize_parameter

num_points = 11
freq = np.arange(1e9, 18e9, 1e7)
ref_freq = 5.6e9
unit = 1e-3
pcb_len = 10
pcb_width = 10
trace_width = 0.38
pcb_prop = common_pcbs["oshpark4"]


def func(min_lines: int):
    sim = Simulation(
        freq=freq, unit=unit, reference_frequency=ref_freq, sim_dir=None
    )
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
        length=pcb_len,
        width=trace_width,
        propagation_axis=Axis("x"),
        port_number=1,
        excite=True,
    )

    Mesh(
        sim=sim,
        metal_res=1 / 80,
        nonmetal_res=1 / 10,
        smooth=(1.1, 1.5, 1.5),
        min_lines=min_lines,
        expand_bounds=((0, 0), (0, 0), (10, 40)),
    )

    sim.run(csx=False)
    return sim.ports[0].impedance()


optimize_parameter(
    func, start=5, step=1, tol=0.2, max_steps=20, display_progress=True
)
