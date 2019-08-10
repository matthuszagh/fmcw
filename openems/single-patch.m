close all
clear
clc

%% Simulation parameters
physical_constants;
% lengths in mm
unit = 1e-3;

## patch.width = 16.14;
patch.width = 20;
## patch.length = 12.09;
patch.length = 11;

% PCB params
substrate.epsR = 4.5;
substrate.kappa = 2e-14;
substrate.width = 2*patch.width;
substrate.length = substrate.width;
substrate.thickness = 1.524;
substrate.cells = 4;

% feedline
## inset = 4.65;
inset = 3.25;
feed.pos = patch.length/2 - inset;
feed.R = 50;

% simulation box
SimBox = [100 100 100];

%% Setup FDTD
f0 = 5.6e9;
fc = 1e9;
FDTD = InitFDTD();
FDTD = SetGaussExcite(FDTD, f0, fc);
BC = {'MUR' 'MUR' 'MUR' 'MUR' 'MUR' 'MUR'};
FDTD = SetBoundaryCond(FDTD, BC);

%% Setup CSXCAD geometry and mesh
CSX = InitCSX();

% initialize mesh
mesh.x = [-SimBox(1)/2 SimBox(1)/2];
mesh.y = [-SimBox(2)/2 SimBox(2)/2];
mesh.z = [-SimBox(3)/2 SimBox(3)/2];

% create patch
CSX = AddMetal(CSX,'patch');
% start and stop are the corner coordinates of the box
patch_start = [-patch.width/2 -patch.length/2 substrate.thickness];
patch_stop  = [ patch.width/2  patch.length/2 substrate.thickness];
CSX = AddBox(CSX, 'patch', 10, patch_start, patch_stop);

% create substrate
CSX = AddMaterial(CSX, 'substrate');
CSX = SetMaterialProperty(CSX, 'substrate', 'Epsilon', substrate.epsR, 'Kappa', substrate.kappa);
substrate_start = [-substrate.width/2 -substrate.length/2 0];
substrate_stop = [ substrate.width/2   substrate.length/2 substrate.thickness];
CSX = AddBox(CSX, 'substrate', 0, substrate_start, substrate_stop);

% add extra cells to substrate
mesh.z = [linspace(0, substrate.thickness, substrate.cells+1) mesh.z];

% ground plane
CSX = AddMetal(CSX, 'gnd');
gnd_start = [-substrate.width/2 -substrate.length/2 0];
gnd_stop = [ substrate.width/2   substrate.length/2 0];
CSX = AddBox(CSX, 'gnd', 10, gnd_start, gnd_stop);

% feedline excitation
feedline_start = [0 -feed.pos 0];
feedline_stop = [0 -feed.pos substrate.thickness];
[CSX port] = AddLumpedPort(CSX, 5, 1, feed.R, feedline_start, feedline_stop, [0 0 1], true);

% finalize mesh
% detect all edges except for patch
mesh = DetectEdges(CSX, mesh, 'ExcludeProperty', 'patch');
% set a special 2D metal edge mesh for patch
mesh = DetectEdges(CSX, mesh, 'SetProperty', 'patch', '2D_Metal_Edge_Res', c0/(f0+fc)/unit/50);
% generate a smooth mesh with max. cell size: lambda_min / 20
mesh = SmoothMesh(mesh, c0/(f0+fc)/unit/20);
CSX = DefineRectGrid(CSX, unit, mesh);

CSX = AddDump(CSX, 'Hf', 'DumpType', 11, 'Frequency', [f0]);
## CSX = AddDump(CSX, 'Hf');
CSX = AddBox(CSX, 'Hf', 10, [-substrate.width -substrate.length -10*substrate.thickness],
             [substrate.width substrate.length 10*substrate.thickness]);

% add a nf2ff calc box; size is 3 cells away from MUR boundary condition
nf2ff_start = [mesh.x(4)     mesh.y(4)     mesh.z(4)];
nf2ff_stop  = [mesh.x(end-3) mesh.y(end-3) mesh.z(end-3)];
[CSX nf2ff] = CreateNF2FFBox(CSX, 'nf2ff', nf2ff_start, nf2ff_stop);

%% Run simulation.
Sim_Path = 'sim';
Sim_CSX = 'patch_ant.xml';

% create an empty working directory
[status, message, messageid] = rmdir( Sim_Path, 's' ); % clear previous directory
[status, message, messageid] = mkdir( Sim_Path ); % create empty simulation folder

% write openEMS compatible xml-file
WriteOpenEMS([Sim_Path '/' Sim_CSX], FDTD, CSX);

% show the structure
CSXGeomPlot([Sim_Path '/' Sim_CSX]);

% run openEMS
RunOpenEMS(Sim_Path, Sim_CSX);

%% Postprocessing & Plots
freq = linspace(f0-fc, f0+fc, 501);
port = calcPort(port, Sim_Path, freq);

%% Smith chart port reflection
## plotRefl(port, 'threshold', -10)
## title('reflection coefficient');

% plot feedline impedance
Zin = port.uf.tot ./ port.if.tot;
figure
plot(freq/1e6, real(Zin), 'k-', 'Linewidth', 1);
hold on
grid on
plot(freq/1e6, imag(Zin), 'r--', 'Linewidth', 1);
title('feedline impedance');
xlabel('frequency (MHz)');
ylabel('impedance Z_{in} (Ohm)');
legend('real', 'imag');

% plot S11
s11 = port.uf.ref ./ port.uf.inc;
figure
plot(freq/1e6, 20*log10(abs(s11)), 'k-', 'Linewidth', 1);
grid on
title('reflection coefficient S_{11}');
xlabel('frequency f (MHz)');
ylabel('reflection coefficient |S_{11}|');

drawnow

%% NFFF Plots
% find resonance frequency from s11
f_res_ind = find(s11==min(s11));
f_res = freq(f_res_ind);

% calculate the far field at phi=0 degrees and at phi=90 degrees
disp('calculating far field at phi=[0 90] deg...');
nf2ff = CalcNF2FF(nf2ff, Sim_Path, f_res, [-180:2:180]*pi/180, [0 90]*pi/180);

% display power and directivity
disp(['radiated power: P_{rad} = ' num2str(nf2ff.Prad) ' Watt']);
disp(['directivity: D_{max} = ' num2str(nf2ff.Dmax) ' (' num2str(10*log10(nf2ff.Dmax)) ' dBi)']);
disp(['efficiency: nu_{rad} = ' num2str(100*nf2ff.Prad./port.P_inc(f_res_ind)) ' %']);

% normalized directivity as polar plot
figure
polarFF(nf2ff, 'xaxis', 'theta', 'param', [1 2], 'normalize', 1)

% log-scale directivity plot
figure
plotFFdB(nf2ff, 'xaxis', 'theta', 'param', [1 2])

drawnow

% Show 3D pattern
disp('calculating 3D far field pattern and dumping to vtk (use Paraview to visualize)...');
thetaRange = (0:2:180);
phiRange = (0:2:360) - 180;
nf2ff = CalcNF2FF(nf2ff, Sim_Path, f_res, thetaRange*pi/180, phiRange*pi/180, 'Verbose', 1, 'Outfile', '3D_Pattern.h5');

figure
plotFF3D(nf2ff, 'logscale', -20);

E_far_normalized = nf2ff.E_norm{1} / max(nf2ff.E_norm{1}(:)) * nf2ff.Dmax;
DumpFF2VTK([Sim_Path '/3D_Pattern.vtk'], E_far_normalized, thetaRange, phiRange, 'scale', unit);
