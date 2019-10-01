`default_nettype none

module dsp #(
   // The default parameter values specify the maximum bit widths for
   // these ports.
   parameter A_DATA_WIDTH = 25,
   parameter B_DATA_WIDTH = 18,
   parameter P_DATA_WIDTH = 48
) (
   input wire                            clk,
   // whether to add new product to old product. 1'b0 is no, 1'b1 is
   // yes.
   input wire                            acc,
   input wire signed [A_DATA_WIDTH-1:0]  a, // 25-bit multiply input
   input wire signed [B_DATA_WIDTH-1:0]  b, // 18-bit multiply input
   output wire signed [P_DATA_WIDTH-1:0] p  // multiply(-accumulate) output
);

   wire [2:0]                            opmode_z = acc ? 3'b010 : 3'b000;

   DSP48E1 #(
      // TODO I think this should be set to 0 to use A as multiplier
      // input and avoid registering it.
      .INMODEREG  (0),
      .ADREG      (0), // don't need preadder register
      .ALUMODEREG (0), // TODO don't register ALUMODE
      .AREG       (0), // don't register A input
      .ACASCREG   (0), // <= AREG
      .BREG       (0), // don't register B input
      .BCASCREG   (0), // <= BREG
      .MREG       (0), // TODO don't need
      .OPMODEREG  (0), // TODO don't register OPMODE
      .PREG       (1), // register P output
      // always use the DSP for multiplication, so don't turn it off
      // to save power.
      .USE_MULT   ("MULTIPLY"),
      .USE_SIMD   ("ONE48") // required when using multiplication
   ) DSP48E1 (
      .ALUMODE       (4'b0000),
      .OPMODE        ({opmode_z, 2'b01, 2'b01}),
      .INMODE        (5'd0), // 0 for unused
      .CEALUMODE     (1'b1), // 1 for unused
      .CEA1          (1'b0), // 0 if AREG=0
      .CEA2          (1'b0), // 0 if AREG=0
      .CEB1          (1'b0), // 0 if BREG=0
      .CEB2          (1'b0), // 0 if BREG=0
      .CEC           (1'b1), // 1 for unused
      .CECARRYIN     (1'b1), // 1 for unused
      .CECTRL        (1'b1), // 0 for OPMODEREG=0
      .CEINMODE      (1'b1), // 1 for unused INMODEREG
      .CEM           (1'b1), // always enable multiply register
      .CEP           (1'b1), // unused P output register
      .MULTSIGNIN    (1'b0), // 0 for unused
      .CARRYINSEL    (3'd0),
      .CARRYIN       (1'b0),
      .CLK           (clk),
      .RSTA          (1'b0),
      .RSTB          (1'b0),
      .RSTC          (1'b0), // 0 for unused
      .RSTD          (1'b0), // 0 for unused
      .RSTCTRL       (1'b0), // 0 for unused opmode reset
      .RSTM          (1'b0),
      .RSTP          (1'b0),
      .RSTALLCARRYIN (1'b0), // 0 for unused
      .RSTALUMODE    (1'b0),
      .RSTINMODE     (1'b0),
      .ACIN          (30'd0),
      .BCIN          (18'd0),
      .PCIN          (48'd0), // 0 for unused
      .C             (48'd0),
      .A             ({5'd0, a}), // upper 5 bits unused during multiply
      .B             (b),
      .P             (p)
   );

endmodule // dsp

`ifdef SIMULATION
`include "DSP48E1.v"
`include "glbl.v"

`timescale 1ns/1ps
module dsp_tb;

   localparam A_DATA_WIDTH = 25;
   localparam B_DATA_WIDTH = 18;
   localparam P_DATA_WIDTH = 48;

   reg clk = 1'b0;
   reg acc = 1'b0;

   // wait for POR to go low.
   always #1 clk = !clk;

   initial begin
      $dumpfile("dsp.vcd");
      $dumpvars(0, dsp_tb);
      // wait for POR
      #100 acc = 1'b0;
      #25 acc = 1'b1;
      #100 $finish;
   end

   reg signed [A_DATA_WIDTH-1:0] a = {A_DATA_WIDTH{1'b0}};
   reg signed [B_DATA_WIDTH-1:0] b = {1'b1, {B_DATA_WIDTH-1{1'b0}}};
   wire signed [P_DATA_WIDTH-1:0] p;

   always @(posedge clk) begin
      if (!dut.DSP48E1.gsr_in) begin
         a <= a + 1'b1;
         b <= b + 1'b1;
      end
   end

   dsp dut (
      .clk (clk),
      .acc   (acc),
      .a     (a),
      .b     (b),
      .p     (p)
   );

endmodule // dsp_tb
`endif
// Local Variables:
// flycheck-verilator-include-path:("/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unimacro/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unisims/")
// End:
