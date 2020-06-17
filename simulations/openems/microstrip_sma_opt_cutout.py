#!/usr/bin/env python

import numpy as np
from pyems.pcb import common_pcbs
from pyems.structure import Microstrip, PCB, Coax, priorities
from pyems.simulation import Simulation
from pyems.coordinate import Coordinate2, Axis, Coordinate3
from pyems.calc import coax_core_diameter, minimize
from pyems.material import common_dielectrics
from pyems.mesh import Mesh
from pyems.field_dump import FieldDump, DumpType
from pyems.utilities import print_table, mil_to_mm

freq = np.arange(0, 18e9, 1e7)
ref_freq = 5.6e9
unit = 1e-3

coax_len = 10
trace_width = 0.38

coax_dielectric = common_dielectrics["PTFE"]
coax_rad = mil_to_mm(190 / 2)  # RG-141

sma_lead_len = 1.9
sma_lead_width = 0.51
sma_lead_height = 0.25
sma_rect_width = 9.53
sma_rect_height = 7.92
sma_rect_length = 0.4
sma_gnd_prong_len = 4.74
sma_gnd_prong_width = 1.02
sma_gnd_prong_height = 1.02

pcb_len = 10
pcb_width = 2 * sma_rect_width


def sim_func(cutout_width: float):
    """
    """
    sim = Simulation(freq=freq, unit=unit, reference_frequency=ref_freq)

    core_rad = (
        coax_core_diameter(
            2 * coax_rad, coax_dielectric.epsr_at_freq(sim.reference_frequency)
        )
        / 2
    )

    pcb_prop = common_pcbs["oshpark4"]
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
        trace_layer=0,
        gnd_layer=1,
        port_number=1,
        ref_impedance=50,
        excite=True,
    )

    # Mueller BU-1420701851 edge mount SMA
    pad = sim.csx.AddConductingSheet(
        "pad",
        conductivity=pcb_prop.metal_conductivity(),
        thickness=pcb_prop.copper_thickness(0),
    )
    pad.AddBox(
        priority=priorities["trace"],
        start=[pcb_len / 2 - sma_lead_len / 2, -sma_lead_width / 2, 0],
        stop=[pcb_len / 2, sma_lead_width / 2, 0],
    )

    pad_cutout = sim.csx.AddMaterial(
        "gnd_cutout",
        epsilon=pcb_prop.substrate.epsr_at_freq(ref_freq),
        kappa=pcb_prop.substrate.kappa_at_freq(ref_freq),
    )
    pad_cutout.AddBox(
        priority=priorities["keepout"],
        start=[
            pcb_len / 2 - sma_lead_len / 2,
            -cutout_width / 2,
            pcb.copper_layer_elevation(1),
        ],
        stop=[pcb_len / 2, cutout_width / 2, pcb.copper_layer_elevation(1)],
    )

    sma_box = sim.csx.AddMetal("sma_box")
    sma_box.AddBox(
        priority=priorities["ground"],
        start=[
            pcb_len / 2,
            -sma_rect_width / 2,
            -sma_rect_height / 2 + sma_lead_height / 2,
        ],
        stop=[
            pcb_len / 2 + sma_rect_length,
            sma_rect_width / 2,
            sma_rect_height / 2 + sma_lead_height / 2,
        ],
    )
    sma_keepout = sim.csx.AddMaterial(
        "sma_keepout",
        epsilon=coax_dielectric.epsr_at_freq(ref_freq),
        kappa=coax_dielectric.kappa_at_freq(ref_freq),
    )
    sma_keepout.AddCylinder(
        priority=priorities["keepout"],
        start=[pcb_len / 2, 0, sma_lead_height / 2],
        stop=[pcb_len / 2 + sma_rect_length, 0, sma_lead_height / 2],
        radius=coax_rad,
    )
    for ypos in [
        -sma_rect_width / 2,
        sma_rect_width / 2 - sma_gnd_prong_width,
    ]:
        # sma_box.AddBox(
        #     priority=priorities["ground"],
        #     start=[pcb_len / 2 - sma_gnd_prong_len, ypos, 0],
        #     stop=[
        #         pcb_len / 2,
        #         ypos + sma_gnd_prong_width,
        #         sma_gnd_prong_height
        #     ],
        # )
        # sma_box.AddBox(
        #     priority=priorities["ground"],
        #     start=[
        #         pcb_len / 2 - sma_gnd_prong_len,
        #         ypos,
        #         pcb.copper_layer_elevation(1)
        #     ],
        #     stop=[
        #         pcb_len / 2,
        #         ypos + sma_gnd_prong_width,
        #         pcb.copper_layer_elevation(1) - sma_gnd_prong_height,
        #     ],
        # )

        sma_box.AddBox(
            priority=priorities["ground"],
            start=[
                pcb_len / 2 - sma_gnd_prong_len,
                ypos,
                pcb.copper_layer_elevation(1) - sma_gnd_prong_height,
            ],
            stop=[
                pcb_len / 2,
                ypos + sma_gnd_prong_width,
                sma_gnd_prong_height,
            ],
        )

    lead = sim.csx.AddMetal("lead")
    lead.AddBox(
        priority=priorities["trace"],
        start=[pcb_len / 2 - sma_lead_len / 2, -sma_lead_width / 2, 0],
        stop=[
            pcb_len / 2 + sma_rect_length,
            sma_lead_width / 2,
            sma_lead_height,
        ],
    )

    # coax port
    Coax(
        sim=sim,
        position=Coordinate3(
            pcb_len / 2 + sma_rect_length + coax_len / 2,
            0,
            sma_lead_height / 2,
        ),
        length=coax_len,
        radius=coax_rad,
        core_radius=core_rad,
        shield_thickness=mil_to_mm(5),
        dielectric=coax_dielectric,
        propagation_axis=Axis("x", direction=-1),
        port_number=2,
        ref_impedance=50,
    )

    mesh = Mesh(
        sim=sim,
        metal_res=1 / 120,
        nonmetal_res=1 / 10,
        min_lines=5,
        expand_bounds=((0, 0), (0, 0), (10, 10)),
    )

    box = mesh.sim_box(include_pml=False)

    sim.run(csx=False)

    s11 = sim.s_param(1, 1)
    s21 = sim.s_param(2, 1)
    print("cutout width: {}".format(cutout_width))
    print_table(
        data=[sim.freq / 1e9, s11, s21],
        col_names=["freq", "s11", "s21"],
        prec=[4, 4, 4],
    )

    return np.sum(s11)


res = minimize(
    sim_func, initial=[sma_lead_width / 2], tol=1e-2, bounds=[(0, None)]
)
print(res)
