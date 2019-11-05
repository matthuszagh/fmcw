yosys -import
read_ilang $::env(TOP_MODULE).ilang
synth_xilinx -top $::env(TOP_MODULE)
hilomap -hicell VCC P -locell GND G
write_edif -top $::env(TOP_MODULE) -nogndvcc $::env(TOP_MODULE).edif
