{ nixpkgs ? (import (builtins.fetchTarball {
  name = "nixos-unstable-2020-07-06";
  url = "https://github.com/nixos/nixpkgs/archive/44fd570d7344fb31d7dd92a42d6e1ef872b5f76b.tar.gz";
  sha256 = "0qxajv68s08m0fsyf4q6dscdn5c4j98hnhz4cls3hhiqvzz86cd1";
}) {})
, openems-pkgs ? (import (builtins.fetchTarball {
  name = "matthuszagh-unstable-2020-08-10";
  url = "https://github.com/matthuszagh/nixpkgs/archive/6b8a978a80e863c6f164fe199b8cd7c616da1639.tar.gz";
  sha256 = "173i1sms6j3waiab2108nbxjqwmbsjdz8v6ymkmgipg80mxjkx30";
}) {
  overlays = [ (import /home/matt/src/dotfiles/nixos/overlays/csxcad.nix) ];
})
, pyspice-pkgs ? (import (builtins.fetchTarball {
    name = "matthuszagh-nixpkgs-pyspice-2020-08-10";
    url = "https://github.com/matthuszagh/nixpkgs/archive/2a3efcd190262ea50b714c8dcc47e0a9767f0cfa.tar.gz";
    sha256 = "0krxh0skf12iidfsk14jymy53as0ccayzccy7hss6mfakz81hp38";
}) {})
}:

let
  pkgs = nixpkgs;
  custompkgs = import <custompkgs> {};
  pythonEnv-pkgs = pyspice-pkgs;
  pythonEnv = (pythonEnv-pkgs.python3.buildEnv.override {
    extraLibs = (with pythonEnv-pkgs.python3Packages; [
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
    ]) ++ (with custompkgs.python3.pkgs; [
      skidl
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
    texlive.combined.scheme-full
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
    asymptote
    imagemagick
    clang

    # pcb cad
    kicad

    # ems
    qucs
    paraview

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
