See doc/fmcw-radar.pdf

#### TODO

* Investigate the possibility of performing FFT processing on the FPGA. This may require an FPGA
  with a higher LUT count. Investigate if the e.g. 50T is pin compatible with the current 15T. The
  goal would be to have the host computer plot the radar output in real-time rather than relying on
  post-processing. It might also be worth looking at the ECP5 FPGA, which seems to give you more per
  dollar and has better open source support.
* Formally verify FPGA code with [SymbiYosys](https://symbiyosys.readthedocs.io/en/latest/quickstart.html).
* Write PC code.
* Consider using a soft processor
  (e.g. [picorv32](https://github.com/cliffordwolf/picorv32/tree/master/picosoc)) for the FPGA
  control logic and configuration.
* Create RF simulations with OpenEMS.
* Create script to ensure all FPGA pins are connected correctly using a JTAG boundary scan.
* Modify FPGA code to allow configuration of the radar via a connected PC, rather than baking the
  logic directly into the FPGA code. This has the benefit that the FPGA logic does not need to be
  resynthesized each time the configurations are changed.
* Improve documentation.
* Remove old files only needed in the previous iteration of this project.
* 3D print mount for radar. This should include a case for the PCB and a mount for the antenna.
