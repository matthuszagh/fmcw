{ pkgs ? (import <nixpkgs> {} // import <custompkgs> {}) }:

let
  libdigital = pkgs.libdigital;
  mh-python = pkgs.python3.withPackages (ps: with ps; [
    libdigital
    matplotlib # TODO replace fully with pyqtgraph
    numpy
    # pylibftdi
    pyqtgraph
  ]);

in
pkgs.mkShell {
  buildInputs = with pkgs; [
    # python3Full
    mh-python
    bitmanip

    # fpga
    yosys
    symbiyosys
    verilator
    verilog
    nextpnr
    gtkwave
    python3Packages.xdot # TODO is this necessary?
    graphviz # TODO should this be a yosys dep?
    vivado-2017-2

    # ftdi
    openocd
    libftdi1

    # software
    valgrind

    # pcb cad
    kicad

    # ems
    openems
    appcsxcad
    hyp2mat

    # 3d printing
    openscad
    (cura.override { plugins = [ pkgs.curaPlugins.octoprint ]; })

    # video
    ffmpeg
  ];
}
