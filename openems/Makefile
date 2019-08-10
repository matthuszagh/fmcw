#global config
config_file = config.json

# single antenna
single_pcb_file = ../hardware/antenna/patch_1x1x5/patch_1x1x5.kicad_pcb

all: single

single:
	pcbmodelgen -p $(single_pcb_file) -c $(config_file) -m kicad_pcb_model.m -g kicad_pcb_mesh.m

.PHONY: all single
