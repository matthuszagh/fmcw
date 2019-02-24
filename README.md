See doc/fmcw-radar.pdf

#### TODO

* Formally verify FPGA code with [SymbiYosys](https://symbiyosys.readthedocs.io/en/latest/quickstart.html).
* Write PC code.
* Consider using a soft processor
  (e.g. [picorv32](https://github.com/cliffordwolf/picorv32/tree/master/picosoc)) for the FPGA
  control logic and configuration.
* Create RF simulations with OpenEMS.
* Create script to ensure all FPGA pins are connected correctly using a JTAG boundary scan.
* Write top level Makefile to bundle everything together.
* Modify FPGA code to allow configuration of the radar via a connected PC, rather than baking the
  logic directly into the FPGA code. This has the benefit that the FPGA logic does not need to be
  resynthesized each time the configurations are changed.
* Improve documentation.
* Remove old files only needed in the previous iteration of this project.
* 3D print mount for radar. This should include a case for the PCB and a mount for the antenna.
* Use a voltage follower to drive power amplifier reference input (needs a much lower impedance source).
