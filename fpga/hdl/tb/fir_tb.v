`default_nettype none

`include "../fmcw_defines.vh"
`include "../fir.v"
`include "pll.v"

`timescale 1ns/1ps
module fir_tb #( `FMCW_DEFAULT_PARAMS );

   reg clk = 1;
   reg signed [IW-1:0] data_i = 1<<<10;
   // reg [IW-1:0] data_i = {{IW-1{1'b0}},1'b1};
   wire [OW-1:0] data_o;
   wire          dv;

   initial begin
      $dumpfile("fir.vcd");
      $dumpvars(0, fir_tb);

      #24 data_i = 0;

      #10000 $finish;
   end

   always #12 clk = !clk;

   fir #(
      .IW            (12),
      .TAPW          (16),
      .NTAPS         (120),
      .OW            (16),
      .CLK_MULT      (12),
      .CLK_MULT_LOG2 (4)
   ) tb (
      .clk_i   (clk),
      .rst_n_i (1'b1),
      .ce_i    (1'b1),
      .dv_o    (dv),
      .data_i  (data_i),
      .data_o  (data_o)
   );

endmodule // fir_tb
