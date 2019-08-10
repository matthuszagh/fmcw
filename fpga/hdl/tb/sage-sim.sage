N = 1024  # input sequence length
Nstages = int(log(N, 4))
T = 2*N  # number of timesteps

# use real dummy vals
real_vals = 0

vars = {}


def set_var(var, val):
    """Convenience function for setting the values of Sage variables."""
    sage_eval('None', cmds="{}={}".format(var, val), locals=vars)


def get_var(var):
    """Convenience function for getting the values of Sage
    variables. Basically, it's just a reminder that we need to access
    the variable through `vars'."""
    return vars[var]


# input sequence
for t in range(T):
    sage_eval('None', cmds="x{0}=var('x{0}')".format(t), locals=vars)

if (real_vals):
    fname = "/home/matt/src/fmcw-radar/fpga/hdl/tb/data{}.txt".format(N)
    with open(fname, "r") as f:
        data = f.readlines()
        data = [x.replace(" ", "") for x in data]
        data = [x.replace("\n", "") for x in data]
        data = [float(x) for x in data]
    for i in range(len(data)):
        set_var("x{}".format(i), data[i])
    for i in range(len(data), T):
        set_var("x{}".format(i), 0)

# set values of select lines
for s in range(Nstages):
    tstart = 0
    for n in range(2*s+1):
        tstart += int(N/(2**(n+1)))
    tstart += 1
    tlen = int(N/(2**(2*s+1)))
    # tend = tstart + N - int(N/(2**(2*s+1)))
    # tend = tstart + int(N/(2**(2*s+1)))
    for t in range(T):
        if (t < tstart):
            val1 = 0
        elif (t == tstart):
            val1 = 1
        elif ((t - tstart) % tlen == 0):
            if (val1 == 1):
                val1 = 0
            else:
                val1 = 1
        set_var("sel_s{}bf1_t{}".format(s, t), val1)

    # if t in range(tstart, tend+1):
    #     set_var("sel_s{}bf1_t{}".format(s, t), 1)
    # else:
    #     set_var("sel_s{}bf1_t{}".format(s, t), 0)

    tstart2 = 0
    for n in range(2*s+2):
        tstart2 += int(N/(2**(n+1)))
    tstart2 += 1
    tlen2 = int(N/(2**(2*s+2)))
    for t in range(T):
        if (t < tstart2):
            val2 = 0
        elif (t == tstart2):
            val2 = 1
        elif ((t - tstart2) % tlen2 == 0):
            if (val2 == 1):
                val2 = 0
            else:
                val2 = 1
        set_var("sel_s{}bf2_t{}".format(s, t), val2)
    # tend = tstart + N - int(N/(2**(2*s+2)))
    # tend = tstart + int(N/(2**(2*s+2)))
    # if t in range(tstart, tend+1):
    #     set_var("sel_s{}bf2_t{}".format(s, t), 1)
    # else:
    #     set_var("sel_s{}bf2_t{}".format(s, t), 0)

# twiddle factors
for s in range(Nstages-1):
    for k in [0, 2, 1, 3]:
        Ngroups = int(N/2**(2*s+2))
        for n in range(Ngroups):
            if (k == 0):
                k_idx = 0
            elif (k == 2):
                k_idx = 1
            elif(k == 1):
                k_idx = 2
            else:
                k_idx = 3
            w = exp(-2*pi*I*4**s*n*k/N)
            offset = 0
            while (get_var("sel_s{}bf2_t{}".format(s, offset)) == 0):
                offset += 1
            # offset += 1
            # TODO this fails for more than 1 multiplier. The values
            # should repeat
            set_var("s{}_w_t{}".format(s, Ngroups*k_idx+n+offset), w)
            for i in range(offset):
                set_var("s{}_w_t{}".format(s, i), 1)
            for i in range(offset+N, T):
                set_var("s{}_w_t{}".format(s, i), 1)

# initialize variables
for t in range(T):
    for s in range(Nstages):
        for n in range(int(N/(2**(2*s+1)))):
            set_var("s{}bf1_fsr{}_t{}".format(s, n, t), 0)
        for n in range(int(N/(2**(2*s+2)))):
            set_var("s{}bf2_fsr{}_t{}".format(s, n, t), 0)

        set_var("s{}bf1_out_t{}".format(s, t), 0)
        set_var("s{}bf2_out_t{}".format(s, t), 0)


# simulation
for t in range(1, T):
    prev_stage_out = 0
    for s in range(Nstages):
        # bf1
        if (s == 0):
            prev_stage_out = get_var("x{}".format(t-1))

        max_fsr_bf1 = int(N/2**(2*s+1)-1)
        for n in range(1, max_fsr_bf1+1):  # shift reg values
            set_var("s{}bf1_fsr{}_t{}".format(s, n, t),
                    get_var("s{}bf1_fsr{}_t{}".format(s, n-1, t-1)))

        if (get_var("sel_s{}bf1_t{}".format(s, t)) == 0):  # mux 0
            set_var("s{}bf1_fsr{}_t{}".format(s, 0, t),
                    prev_stage_out)
            set_var("s{}bf1_out_t{}".format(s, t),
                    get_var("s{}bf1_fsr{}_t{}".format(s, max_fsr_bf1, t-1)))
        else:
            set_var("s{}bf1_fsr{}_t{}".format(s, 0, t),
                    get_var("s{}bf1_fsr{}_t{}".format(s, max_fsr_bf1, t-1))
                    - prev_stage_out)
            set_var("s{}bf1_out_t{}".format(s, t),
                    get_var("s{}bf1_fsr{}_t{}".format(s, max_fsr_bf1, t-1))
                    + prev_stage_out)

        prev_stage_out = get_var("s{}bf1_out_t{}".format(s, t))

        # bf2
        max_fsr_bf2 = int(max_fsr_bf1/2)
        for n in range(1, max_fsr_bf2+1):  # shift reg values
            set_var("s{}bf2_fsr{}_t{}".format(s, n, t),
                    get_var("s{}bf2_fsr{}_t{}".format(s, n-1, t-1)))

        if (get_var("sel_s{}bf2_t{}".format(s, t)) == 0):
            set_var("s{}bf2_fsr{}_t{}".format(s, 0, t),
                    prev_stage_out)
            set_var("s{}bf2_out_t{}".format(s, t),
                    get_var("s{}bf2_fsr{}_t{}".format(s, max_fsr_bf2, t-1)))
        elif (get_var("sel_s{}bf2_t{}".format(s, t)) == 1 and
              get_var("sel_s{}bf1_t{}".format(s, t)) == 1):
            set_var("s{}bf2_fsr{}_t{}".format(s, 0, t),
                    get_var("s{}bf2_fsr{}_t{}".format(s, max_fsr_bf2, t-1))
                    - prev_stage_out)
            set_var("s{}bf2_out_t{}".format(s, t),
                    get_var("s{}bf2_fsr{}_t{}".format(s, max_fsr_bf2, t-1))
                    + prev_stage_out)
        else:
            set_var("s{}bf2_fsr{}_t{}".format(s, 0, t),
                    get_var("s{}bf2_fsr{}_t{}".format(s, max_fsr_bf2, t-1))
                    - imag(prev_stage_out)
                    + I*real(prev_stage_out))
            set_var("s{}bf2_out_t{}".format(s, t),
                    get_var("s{}bf2_fsr{}_t{}".format(s, max_fsr_bf2, t-1))
                    + imag(prev_stage_out)
                    - I*real(prev_stage_out))

        if (s % 2 == 0 and s < Nstages-1):  # pre-multiplier
            set_var("s{}bf2_out_t{}".format(s, t),
                    get_var("s{}bf2_out_t{}".format(s, t))
                    * get_var("s{}_w_t{}".format(s, t)))

        prev_stage_out = get_var("s{}bf2_out_t{}".format(s, t))

        if (s == Nstages-1):
            if (t >= N):
                if (real_vals):
                    print("t={}: {}".format(
                        t-N, numerical_approx(prev_stage_out)))
                else:
                    print("t={}: {}".format(t-N, prev_stage_out))
