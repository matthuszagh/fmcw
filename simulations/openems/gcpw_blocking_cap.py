#!/usr/bin/env python

import numpy as np
import CSXCAD as csxcad
import openEMS as openems
from pyems.pcb import common_pcbs
from pyems.port import MicrostripPort
from pyems.simulation import Simulation
from pyems.field_dump import FieldDump
from pyems.network import Network
from pyems.utilities import pretty_print, wavelength


pcb = common_pcbs["oshpark4"]
z0_target = 50
center_freq = 5.6e9
delta_freq = 2e9
unit = 1e-3  # all units in mm
gap_width = 0.1524
via_width = 1.27
width = 0.34

cap_len = 1
cap_width = 0.5
cap_height = 0.5
cap_gap = gap_width
cap_via_gap = via_width / 2 - (width / 2) - gap_width
pad_dim = cap_width
gnd_cutout_width = 1.2 * pad_dim

fdtd = openems.openEMS(EndCriteria=1e-5)
csx = csxcad.ContinuousStructure()

csx.GetGrid().SetDeltaUnit(unit)

trace_len = 30
sub_width = 10

port1 = MicrostripPort(
    csx=csx,
    bounding_box=[
        [-trace_len / 2, -width / 2, -pcb.layer_separation(unit)[0]],
        [-cap_len / 2 - (pad_dim / 2), width / 2, 0],
    ],
    thickness=unit * pcb.layer_thickness(unit)[0],
    conductivity=pcb.metal_conductivity(),
    excite=True,
    ref_resistance=50,
)
port2 = MicrostripPort(
    csx=csx,
    bounding_box=[
        [trace_len / 2, width / 2, -pcb.layer_separation(unit)[0]],
        [cap_len / 2 + (pad_dim / 2), -width / 2, 0],
    ],
    thickness=unit * pcb.layer_thickness(unit)[0],
    conductivity=pcb.metal_conductivity(),
    excite=False,
    ref_resistance=50,
)

substrate = csx.AddMaterial(
    "substrate",
    epsilon=pcb.epsr_at_freq(center_freq),
    kappa=pcb.substrate_conductivity(),
)
substrate.AddBox(
    priority=0,
    start=[-trace_len / 2, -sub_width / 2, -pcb.layer_separation(unit)[0]],
    stop=[trace_len / 2, sub_width / 2, 0],
)

ground = csx.AddConductingSheet(
    "ground",
    conductivity=pcb.metal_conductivity(),
    thickness=unit * pcb.layer_thickness(unit)[0],
)
# layer 1 (-x, -y)
ground.AddBox(
    priority=999,
    start=[-trace_len / 2, -sub_width / 2, 0],
    stop=[-cap_len / 2 - (pad_dim), -width / 2 - gap_width, 0],
)
# vias (-x, -y)
ground.AddBox(
    priority=999,
    start=[-trace_len / 2, -via_width / 2, -pcb.layer_separation(unit)[0]],
    stop=[-cap_len / 2 - (pad_dim), -via_width / 2, 0],
)
# layer 1 (+x, -y)
ground.AddBox(
    priority=999,
    start=[cap_len / 2 + (pad_dim), -sub_width / 2, 0],
    stop=[trace_len / 2, -width / 2 - gap_width, 0],
)
# layer 1 (, -y)
ground.AddBox(
    priority=999,
    start=[-cap_len / 2 - (pad_dim), -sub_width / 2, 0],
    stop=[cap_len / 2 + (pad_dim), -pad_dim / 2 - cap_gap, 0],
)
# vias (, -y)
ground.AddBox(
    priority=999,
    start=[
        -cap_len / 2 - (pad_dim),
        -pad_dim / 2 - cap_gap - cap_via_gap,
        -pcb.layer_separation(unit)[0],
    ],
    stop=[cap_len / 2 + (pad_dim), -pad_dim / 2 - cap_gap - cap_via_gap, 0],
)
# vias (+x, -y)
ground.AddBox(
    priority=999,
    start=[
        cap_len / 2 + (pad_dim),
        -via_width / 2,
        -pcb.layer_separation(unit)[0],
    ],
    stop=[trace_len / 2, -via_width / 2, 0],
)
# layer 1 (-x, +y)
ground.AddBox(
    priority=999,
    start=[-trace_len / 2, width / 2 + gap_width, 0],
    stop=[-cap_len / 2 - (pad_dim), sub_width / 2, 0],
)
# vias (-x, +y)
ground.AddBox(
    priority=999,
    start=[-trace_len / 2, via_width / 2, -pcb.layer_separation(unit)[0]],
    stop=[-cap_len / 2 - (pad_dim), via_width / 2, 0],
)
# layer 1 (+x, +y)
ground.AddBox(
    priority=999,
    start=[cap_len / 2 + (pad_dim), width / 2 + gap_width, 0],
    stop=[trace_len / 2, sub_width / 2, 0],
)
# vias (+x, -y)
ground.AddBox(
    priority=999,
    start=[
        cap_len / 2 + (pad_dim),
        via_width / 2,
        -pcb.layer_separation(unit)[0],
    ],
    stop=[trace_len / 2, via_width / 2, 0],
)
# vias (, +y)
ground.AddBox(
    priority=999,
    start=[
        -cap_len / 2 - (pad_dim),
        pad_dim / 2 + cap_gap + cap_via_gap,
        -pcb.layer_separation(unit)[0],
    ],
    stop=[cap_len / 2 + (pad_dim), pad_dim / 2 + cap_gap + cap_via_gap, 0],
)
# layer 1 (, +y)
ground.AddBox(
    priority=999,
    start=[-cap_len / 2 - (pad_dim), pad_dim / 2 + cap_gap, 0],
    stop=[cap_len / 2 + (pad_dim), sub_width / 2, 0],
)

ground.AddPolygon(
    [
        [
            -cap_len / 2 - pad_dim,
            -cap_len / 2 - pad_dim,
            -cap_len / 2 - (pad_dim / 2),
        ],
        [
            -width / 2 - gap_width,
            -pad_dim / 2 - cap_gap,
            -pad_dim / 2 - cap_gap,
        ],
    ],
    "z",
    0,
    priority=999,
)
ground.AddPolygon(
    [
        [
            -cap_len / 2 - pad_dim,
            -cap_len / 2 - pad_dim,
            -cap_len / 2 - (pad_dim / 2),
        ],
        [width / 2 + gap_width, pad_dim / 2 + cap_gap, pad_dim / 2 + cap_gap],
    ],
    "z",
    0,
    priority=999,
)
ground.AddPolygon(
    [
        [
            cap_len / 2 + pad_dim,
            cap_len / 2 + pad_dim,
            cap_len / 2 + (pad_dim / 2),
        ],
        [
            -width / 2 - gap_width,
            -pad_dim / 2 - cap_gap,
            -pad_dim / 2 - cap_gap,
        ],
    ],
    "z",
    0,
    priority=999,
)
ground.AddPolygon(
    [
        [
            cap_len / 2 + pad_dim,
            cap_len / 2 + pad_dim,
            cap_len / 2 + (pad_dim / 2),
        ],
        [width / 2 + gap_width, pad_dim / 2 + cap_gap, pad_dim / 2 + cap_gap],
    ],
    "z",
    0,
    priority=999,
)
# bottom layer ground plane
inner_ground = csx.AddConductingSheet(
    "inner_ground",
    conductivity=pcb.metal_conductivity(),
    thickness=unit * pcb.layer_thickness(unit)[1],
)
inner_ground.AddBox(
    priority=10,
    start=[-trace_len / 2, -sub_width / 2, -pcb.layer_separation(unit)[0]],
    stop=[trace_len / 2, sub_width / 2, -pcb.layer_separation(unit)[0]],
)
# ground cutout
air = csx.AddMaterial("air", epsilon=1)
air.AddBox(
    priority=999,
    start=[
        -cap_len / 2 - (pad_dim / 2),
        -gnd_cutout_width / 2,
        -pcb.layer_separation(unit)[0],
    ],
    stop=[
        cap_len / 2 + (pad_dim / 2),
        gnd_cutout_width / 2,
        -pcb.layer_separation(unit)[0],
    ],
)

# capacitor
pad = csx.AddConductingSheet(
    "pad",
    conductivity=pcb.metal_conductivity(),
    thickness=unit * pcb.layer_thickness(unit)[0],
)
pad.AddBox(
    priority=999,
    start=[-cap_len / 2 - (pad_dim / 2), -pad_dim / 2, 0],
    stop=[-cap_len / 2 + (pad_dim / 2), pad_dim / 2, 0],
)
pad.AddPolygon(
    [
        [
            -cap_len / 2 - pad_dim,
            -cap_len / 2 - (pad_dim / 2),
            -cap_len / 2 - (pad_dim / 2),
        ],
        [-width / 2, -width / 2, -pad_dim / 2],
    ],
    "z",
    0,
    priority=999,
)
pad.AddPolygon(
    [
        [
            -cap_len / 2 - pad_dim,
            -cap_len / 2 - (pad_dim / 2),
            -cap_len / 2 - (pad_dim / 2),
        ],
        [width / 2, width / 2, pad_dim / 2],
    ],
    "z",
    0,
    priority=999,
)
pad.AddPolygon(
    [
        [
            cap_len / 2 + pad_dim,
            cap_len / 2 + (pad_dim / 2),
            cap_len / 2 + (pad_dim / 2),
        ],
        [-width / 2, -width / 2, -pad_dim / 2],
    ],
    "z",
    0,
    priority=999,
)
pad.AddPolygon(
    [
        [
            cap_len / 2 + (pad_dim / 2),
            cap_len / 2 + (pad_dim / 2),
            cap_len / 2 + pad_dim,
        ],
        [pad_dim / 2, width / 2, width / 2],
    ],
    "z",
    0,
    priority=999,
)
pad.AddBox(
    priority=999,
    start=[cap_len / 2 - (pad_dim / 2), -pad_dim / 2, 0],
    stop=[cap_len / 2 + (pad_dim / 2), pad_dim / 2, 0],
)
# based on Murata GJM1555C1H100FB01 (ESR at 6GHz)
cap = csx.AddLumpedElement("cap", ny=0, caps=True, R=0.7, C=10e-12, L=4.4e-10)
cap.AddBox(
    priority=999,
    start=[-cap_len / 2, -cap_width / 2, 0],
    stop=[cap_len / 2, cap_width / 2, cap_height],
)

network = Network(csx=csx, ports=[port1, port2])
network.generate_mesh(
    min_wavelength=wavelength(center_freq + delta_freq, unit),
    metal_res=1 / 160,
    nonmetal_res=1 / 80,
    smooth=[1.1, 1.3, 1.3],
    min_lines=5,
    expand_bounds=[[0, 0], [8, 8], [8, 8]],
)
network.view()

field_dump = FieldDump(
    csx=csx,
    box=[
        [-trace_len / 2, -sub_width / 2, 0],
        [trace_len / 2, sub_width / 2, 0],
    ],
)
sim = Simulation(
    fdtd=fdtd,
    csx=csx,
    center_freq=center_freq,
    half_bandwidth=delta_freq,
    boundary_conditions=["PML_8", "PML_8", "PML_8", "PML_8", "PML_8", "PML_8"],
    network=network,
    field_dumps=[field_dump],
)
sim.simulate()
sim.view_field()

freq = sim.get_freq()

s21 = network.s_param(2, 1)
s11 = network.s_param(1, 1)
ports = network.get_ports()

pretty_print(
    np.concatenate(([freq / 1e9], [s11], [s21])),
    col_names=["freq", "s11", "s21"],
    prec=[4, 4, 4],
)
