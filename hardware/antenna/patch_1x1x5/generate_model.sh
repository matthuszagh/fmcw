#!/bin/bash

pcb_file=patch_1x1x5.kicad_pcb
config_file=config.json

# Generate octave script files with model and mesh grid
pcbmodelgen -p $pcb_file -c $config_file -m kicad_pcb_model.m -g kicad_pcb_mesh.m
