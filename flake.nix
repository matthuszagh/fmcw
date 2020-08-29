{
  description = "6GHz frequency-modulated continuous-wave radar with real-time range detection";

  inputs.nixpkgs.url = github:nixos/nixpkgs/master;
  inputs.nixos.url = github:matthuszagh/nixos/master;

  outputs =
    { self
    , nixpkgs
    , nixos
    }: {
      devShell.x86_64-linux =
        let
          system = "x86_64-linux";
          npkgs = import nixpkgs { inherit system; };
          pkgs = nixos.packages."${system}";
          pythonEnv = pkgs.python3.withPackages (p: with p; [
            pyems
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
            python-openems
            python-csxcad
          ]);
        in
        npkgs.mkShell {
          buildInputs = [
            pythonEnv
          ] ++ (with pkgs; [
            # fpga
            yosys
            symbiyosys
            verilator
            verilog
            # nextpnr
            gtkwave

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
            octave
            openems
            appcsxcad
            hyp2mat
            paraview

            # 3d printing
            openscad
            # TODO fix
            # freecad
            # TODO fix
            # (cura.override { plugins = [ pkgs.curaPlugins.octoprint ]; })
            # curaengine
          ]);
        };
    };
}
