{ nixpkgs ? (import (builtins.fetchTarball {
  name = "nixos-unstable-2020-07-06";
  url = "https://github.com/nixos/nixpkgs/archive/44fd570d7344fb31d7dd92a42d6e1ef872b5f76b.tar.gz";
  sha256 = "0qxajv68s08m0fsyf4q6dscdn5c4j98hnhz4cls3hhiqvzz86cd1";
}) {})
, openems-pkgs ? (import (builtins.fetchTarball {
  name = "matthuszagh-unstable-2020-04-06";
  url = "https://github.com/matthuszagh/nixpkgs/archive/ad725f423cd187034e70ee639ae9eea751112c58.tar.gz";
  sha256 = "0pdyzv4yzb8hscrsqmf3qshzsry0gx5mzc98gkbgab13yvhj35qp";
}) {})
}:

let
  pkgs = nixpkgs;
  custompkgs = import <custompkgs> {};
  pythonEnv = (pkgs.python3Full.buildEnv.override {
    extraLibs = (with pkgs.python3Packages; [
      matplotlib
      bitstring
      numpy
      pyqtgraph
      cocotb
      pyclipper
      simplejson
      # TODO fix
      # nmigen
      cython
      # migen
    ]) ++ (with custompkgs; [
      # skidl
      pyems
    ]) ++ (with openems-pkgs.python3Packages; [
      python-openems
      python-csxcad
    ]);
    ignoreCollisions = true;
  });
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    pythonEnv
    custompkgs.pyems
    pkg-config

    # fpga
    yosys
    symbiyosys
    verilator
    verilog
    # nextpnr
    gtkwave
    python3Packages.xdot
    graphviz

    # ftdi
    openocd
    libftdi1

    # software
    valgrind

    # pcb cad
    kicad

    # ems
    qucs

    # 3d printing
    openscad
    # TODO fix
    # freecad
    # TODO fix
    # (cura.override { plugins = [ pkgs.curaPlugins.octoprint ]; })
    # curaengine
  ] ++ (with custompkgs; [
    ebase
    vivado-2017-2
  ]) ++ (with openems-pkgs; [
    openems
    appcsxcad
    hyp2mat
  ]);

  KICAD_SYMBOL_DIR="/home/matt/src/kicad-symbols";
}
