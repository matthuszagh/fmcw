`ifndef _DUAL_FF_V_
`define _DUAL_FF_V_

`default_nettype none
`timescale 1ns/1ps

// Dual-edge triggered flip flop.

module dual_ff #(
   parameter WIDTH = 1
) (
   input wire              clk,
   input wire [WIDTH-1:0]  dp,
   input wire [WIDTH-1:0]  dn,
   output wire [WIDTH-1:0] q
);
   reg [WIDTH-1:0] p = {WIDTH{1'b0}};
   reg [WIDTH-1:0] n = {WIDTH{1'b0}};

   always @(posedge clk) begin
      p <= dp ^ n;
   end

   always @(negedge clk) begin
      n <= dn ^ p;
   end

   assign q = p ^ n;

`ifdef FORMAL
 `ifdef DUAL_FF
  `define ASSUME assume
 `else
  `define ASSUME assert
 `endif

   (* gclk *) reg gclk;
   reg     past_valid = 0;
   always @(posedge gclk) begin
      past_valid <= 1;
      if (past_valid) begin
         if ($rose(clk)) begin
            assert (q == $past(dp));
         end else if ($fell(clk)) begin
            assert (q == $past(dn));
         end
      end
   end

`endif

endmodule
`endif
