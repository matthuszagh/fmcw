`default_nettype none

// `mult_add' uses a DSP element to perform the operation p = a*b+c

module mult_add #(
   parameter A_DATA_WIDTH = 25,
   parameter B_DATA_WIDTH = 18,
   parameter C_DATA_WIDTH = 48,
   parameter P_DATA_WIDTH = 48
) (
   input wire signed [A_DATA_WIDTH-1:0]  a, // 25-bit multiply input
   input wire signed [B_DATA_WIDTH-1:0]  b, // 18-bit multiply input
   input wire signed [C_DATA_WIDTH-1:0]  c, // 48-bit adder input
   output wire signed [P_DATA_WIDTH-1:0] p  // output
);

   localparam A_TOTAL_DATA_WIDTH = 25;
   localparam B_TOTAL_DATA_WIDTH = 18;
   localparam C_TOTAL_DATA_WIDTH = 48;
   localparam P_TOTAL_DATA_WIDTH = 48;

   localparam A_PADDING = A_TOTAL_DATA_WIDTH - A_DATA_WIDTH;
   localparam B_PADDING = B_TOTAL_DATA_WIDTH - B_DATA_WIDTH;
   localparam C_PADDING = C_TOTAL_DATA_WIDTH - C_DATA_WIDTH;
   localparam P_PADDING = P_TOTAL_DATA_WIDTH - P_DATA_WIDTH;

   wire [2:0]                            opmode_z = 3'b011;

   wire [P_PADDING-1:0]                  p_unused;

   function [A_TOTAL_DATA_WIDTH-1:0] sign_extend_a(input [A_DATA_WIDTH-1:0] expr);
      sign_extend_a = (expr[A_DATA_WIDTH-1] == 1'b1) ? {{A_PADDING{1'b1}}, expr}
                      : {{A_PADDING{1'b0}}, expr};
   endfunction
   function [B_TOTAL_DATA_WIDTH-1:0] sign_extend_b(input [B_DATA_WIDTH-1:0] expr);
      sign_extend_b = (expr[B_DATA_WIDTH-1] == 1'b1) ? {{B_PADDING{1'b1}}, expr}
                      : {{B_PADDING{1'b0}}, expr};
   endfunction
   function [C_TOTAL_DATA_WIDTH-1:0] sign_extend_c(input [C_DATA_WIDTH-1:0] expr);
      sign_extend_c = (expr[C_DATA_WIDTH-1] == 1'b1) ? {{C_PADDING{1'b1}}, expr}
                      : {{C_PADDING{1'b0}}, expr};
   endfunction

   wire [A_TOTAL_DATA_WIDTH-1:0]         a_extended = sign_extend_a(a);
   wire [B_TOTAL_DATA_WIDTH-1:0]         b_extended = sign_extend_b(b);
   wire [C_TOTAL_DATA_WIDTH-1:0]         c_extended = sign_extend_c(c);

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
      .CREG       (0),
      .MREG       (0), // TODO don't need
      .OPMODEREG  (0), // TODO don't register OPMODE
      .PREG       (0), // register P output
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
      .C             (c_extended),
      .A             ({5'd0, a_extended}), // upper 5 bits unused during multiply
      .B             (b_extended),
      .P             ({p_unused, p})
   );

endmodule

`ifdef MULT_ADD_SIMULATE
`include "DSP48E1.v"
`include "glbl.v"

`timescale 1ns/1ps
module mult_add_tb;

   localparam A_DATA_WIDTH = 25;
   localparam B_DATA_WIDTH = 16;
   localparam C_DATA_WIDTH = 41;
   localparam P_DATA_WIDTH = 41;

   reg clk = 1'b0;

   // wait for POR to go low.
   always #1 clk = !clk;

   initial begin
      $dumpfile("tb/mult_add_tb.vcd");
      $dumpvars(0, mult_add_tb);
      #200 $finish;
   end

   reg signed [A_DATA_WIDTH-1:0] a = {A_DATA_WIDTH{1'b0}};
   reg signed [B_DATA_WIDTH-1:0] b = {1'b1, {B_DATA_WIDTH-1{1'b0}}};
   reg signed [C_DATA_WIDTH-1:0] c = {{C_DATA_WIDTH-3{1'b0}}, 3'd5};
   wire signed [P_DATA_WIDTH-1:0] p;

   always @(posedge clk) begin
      if (!dut.DSP48E1.gsr_in) begin
         a <= a + 1'b1;
         b <= b + 1'b1;
         c <= c * 2;
      end
   end

   mult_add #(
      .A_DATA_WIDTH (A_DATA_WIDTH),
      .B_DATA_WIDTH (B_DATA_WIDTH),
      .C_DATA_WIDTH (C_DATA_WIDTH),
      .P_DATA_WIDTH (P_DATA_WIDTH)
   ) dut (
      .a   (a),
      .b   (b),
      .c   (c),
      .p   (p)
   );

endmodule
`endif
// Local Variables:
// flycheck-verilator-include-path:("/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unimacro/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unisims/")
// End:
