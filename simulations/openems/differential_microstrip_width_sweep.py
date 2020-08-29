#!/usr/bin/env python

import numpy as np
from pyems.simulation import Simulation
from pyems.pcb import common_pcbs
from pyems.structure import DifferentialMicrostrip, PCB
from pyems.coordinate import Coordinate2, Axis, Box3, Coordinate3
from pyems.utilities import print_table, mil_to_mm
from pyems.field_dump import FieldDump, DumpType
from pyems.mesh import Mesh
from pyems.calc import sweep

freq = np.arange(0, 18e9, 10e6)
unit = 1e-3
ref_freq = 5.6e9

pcb_len = 10
pcb_width = 10

mid_width = 0.85
trace_gap = mil_to_mm(5)

def func(width: float):
    sim = Simulation(freq=freq, unit=unit, reference_frequency=ref_freq, sim_dir=None)
    pcb_prop = common_pcbs["oshpark4"]
    pcb = PCB(
        sim=sim,
        pcb_prop=pcb_prop,
        length=pcb_len,
        width=pcb_width,
        layers=range(3),
        omit_copper=[0],
    )

    DifferentialMicrostrip(
        pcb=pcb,
        position=Coordinate2(0, 0),
        length=pcb_len,
        width=width,
        gap=trace_gap,
        propagation_axis=Axis("x"),
        port_number=1,
        excite=True,
        ref_impedance=50,
    )

    Mesh(
        sim=sim,
        metal_res=1 / 80,
        nonmetal_res=1 / 10,
        min_lines=9,
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

    sim.run(csx=False)
    return np.abs(sim.ports[0].impedance(freq=ref_freq))

widths = np.arange(0.75 * mid_width, 1.25 * mid_width, 0.05 * mid_width)
sim_vals = sweep(func, widths, processes=11)

print_table(
    data=[widths, sim_vals],
    col_names=["width", "z0"],
    prec=[4, 4],
)
