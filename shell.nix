{ nixpkgs ? (import (builtins.fetchTarball {
  name = "nixos-unstable-2020-07-06";
  url = "https://github.com/nixos/nixpkgs/archive/44fd570d7344fb31d7dd92a42d6e1ef872b5f76b.tar.gz";
  sha256 = "0qxajv68s08m0fsyf4q6dscdn5c4j98hnhz4cls3hhiqvzz86cd1";
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
      python-openems
      python-csxcad
    ]);
    ignoreCollisions = true;
  });
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    pythonEnv
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
    openems
    appcsxcad
    hyp2mat
    vivado-2017-2
  ]);

  KICAD_SYMBOL_DIR="/home/matt/src/kicad-symbols";
}
