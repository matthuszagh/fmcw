#!/usr/bin/env python
"""
Test the effect of different linear taper angles/lengths on S11 and S21.
"""

import numpy as np
from pyems.pcb import common_pcbs
from pyems.simulation import Simulation
from pyems.utilities import print_table
from pyems.structure import PCB, Microstrip, Taper
from pyems.coordinate import Box2, Coordinate2, Axis
from pyems.mesh import Mesh
from pyems.calc import sweep

unit = 1e-3
freq_res = 1e7
freq = np.arange(0, 18e9 + freq_res, freq_res)
pcb_prop = common_pcbs["oshpark4"]
pcb_len = 10
pcb_width = 5
trace_width = 0.38
z0_ref = 50

microstrip_discontinuity_width = 0.5
microstrip_discontinuity_length = 1


def sim_func(taper_angle: float):
    """
    :param taper_angle: Linear taper angle in degrees.
    """
    angle_rad = taper_angle * np.pi / 180
    dy = np.abs(trace_width - microstrip_discontinuity_width) / 2
    dx = dy / np.tan(angle_rad)
    taper_middle = microstrip_discontinuity_length / 2 + dx / 2
    taper_end = microstrip_discontinuity_length / 2 + dx

    sim = Simulation(freq=freq, unit=unit, sim_dir=None)
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

    Taper(
        pcb=pcb,
        position=Coordinate2(-taper_middle, 0),
        pcb_layer=0,
        width1=trace_width,
        width2=microstrip_discontinuity_width,
        length=dx,
    )
    Taper(
        pcb=pcb,
        position=Coordinate2(taper_middle, 0),
        pcb_layer=0,
        width1=microstrip_discontinuity_width,
        width2=trace_width,
        length=dx,
    )

    box = Box2(
        Coordinate2(-pcb_len / 2, -trace_width / 2),
        Coordinate2(-taper_end, trace_width / 2),
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
        Coordinate2(taper_end, -trace_width / 2),
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

    # sim.run(csx=False)
    sim.run()
    return sim.s_param(1, 1)


angles = np.arange(10, 90, 10)
angles = [10]
res = sweep(sim_func, angles, processes=5)

str_angles = [str(angle) for angle in angles]
print_table(
    data=np.concatenate(([freq / 1e9], res)),
    col_names=["freq"] + str_angles,
    prec=[2] + [4 for _ in angles],
)
