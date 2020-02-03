`ifndef _DUAL_FF_V_
`define _DUAL_FF_V_

`default_nettype none
`timescale 1ns/1ps

module dual_ff #(
   parameter DATA_WIDTH = 1
) (
   input wire                   clk,
   input wire                   rst_n,
   input wire [DATA_WIDTH-1:0]  dp,
   input wire [DATA_WIDTH-1:0]  dn,
   output wire [DATA_WIDTH-1:0] q
);
   reg [DATA_WIDTH-1:0] p, n;

   always @(posedge clk) begin
      if (!rst_n)
        p <= 1'b0;
      else
        p <= dp ^ n;
   end

   always @(negedge clk) begin
      if (!rst_n)
        n <= 1'b0;
      else
        n <= dn ^ p;
   end

   assign q = p ^ n;

endmodule
`endif
