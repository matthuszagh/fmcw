{ pkgs ? (import <nixpkgs> {})
}:

let
  custompkgs = import <custompkgs> {};
  # pkgs = (nixpkgs // custompkgs);
  pythonEnv = (pkgs.python3Full.buildEnv.override {
    extraLibs = (with pkgs.python3Packages; [
      matplotlib
      bitstring
      numpy
      pyqtgraph
      cocotb
      pyclipper
      simplejson
      nmigen
      migen
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
    freecad
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
