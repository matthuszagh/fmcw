close all; clear all;

n = 120; % # taps.
fs = 40e6; % Sampling frequency.
fn = fs/2; % Nyquist frequency.
f = [0 1.5e6 2e6 fn]/fn; % Frequency at the band edges.
a = [1 1 0 0]; % Amplitude at the band edges.

%% Number of taps should be made available for parameterizing HDL files.
yml_fid = fopen("hdl_params.yml", "w");
fprintf(yml_fid, "NTAPS: %d\n", n);
fclose(yml_fid);

ripple_pass_db = 1.0;
att_stop_db = -40;

%% Compute weights based on desired ripple and stopband attenuation.
w = [1/(1-10^(-ripple_pass_db/20)) 1/(10^(att_stop_db/20))];

%% Compute impulse response.
H = remez(n-1, f, a, w);
%% Plot frequency response.
figure(1);
clf();
freqz(H);
print -dsvg H

%% Write impulse response to file.
fid = fopen('fir_coeffs.dbl', 'w');
for i=1:size(H)
  fprintf(fid, '%f\n', H(i));
end
fclose(fid);
