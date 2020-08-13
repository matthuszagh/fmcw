#!/usr/bin/env python

from skidl.pyspice import (
    Part,
    generate_netlist,
    gnd,
    node,
    no_files,
)
import numpy as np

no_files()

ref_impedance = 50

num_nodes = int(1e3)
delay_t = 1e-11
end_t = 17 * delay_t
step_time = 1e-12
vpos_val = 5

pulse_vals = []
sine_per = delay_t * 4
sine_freq = 2 * np.pi / sine_per
sine_per4 = sine_per / 4
num_vals = int(sine_per4 / step_time)
for i in range(num_vals):
    t = i * step_time
    pulse_vals.append((t, vpos_val * np.sin(sine_freq * t)))

pulse_vals.append((end_t+step_time, vpos_val))

vs = Part(
    "pyspice",
    "PWLV",
    values=pulse_vals,
)

rs = Part("pyspice", "R", value=ref_impedance)
rl = Part("pyspice", "R", value=ref_impedance)

ls = []
cs = []

trace_len = 7.56
cap_per_mm = 0.110258e-12
cap_val = trace_len * cap_per_mm / num_nodes
induct_val = ref_impedance ** 2 * cap_val

for i in range(num_nodes):
    ls.append(Part("pyspice", "L", value=induct_val))
    cs.append(Part("pyspice", "C", value=cap_val))
    cs[i]["n"] += gnd
    cs[i]["p"] += ls[i][2]
    if not i == 0:
        ls[i][1] += ls[i - 1][2]

vs["n"] += gnd, rl["n"]
vs["p"] += rs[1]
rs[2] += ls[0][1]
rl["p"] += cs[num_nodes - 1]["p"]

circ = generate_netlist()
sim = circ.simulator()
waveforms = sim.transient(step_time=step_time, end_time=end_t)

time = waveforms.time.as_ndarray()

vs = [
    waveforms[node(vs["p"])].as_ndarray(),
    waveforms[node(rs[2])].as_ndarray(),
]
for i in range(num_nodes):
    vs.append(waveforms[node(cs[i]["p"])].as_ndarray())

with open(".data/tx_line.dat", "w") as f:
    # f.write("t ")
    # for i in range(num_nodes):
    #     f.write("v{} ".format(i))
    # f.write("\n")

    for i, timeval in enumerate(time):
        f.write("{:.6} ".format(timeval))
        for j in range(num_nodes):
            f.write("{:.6} ".format(vs[j][i]))
        f.write("\n")
