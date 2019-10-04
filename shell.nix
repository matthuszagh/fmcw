{ pkgs ? (import <nixpkgs> {} // import <custompkgs> {}) }:

let
  libdigital = pkgs.libdigital;
  mh-python = pkgs.python3.withPackages (ps: with ps; [
    libdigital
    matplotlib
    numpy
  ]);

in
pkgs.mkShell {
  buildInputs = with pkgs; [
    mh-python
    bitmanip
  ];

  shellHook = ''
    export PYTHONPATH="$(python -c "import site; print(site.getsitepackages()[0])")"
  '';
}
