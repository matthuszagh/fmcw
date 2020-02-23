`ifndef _DUAL_FF_V_
`define _DUAL_FF_V_

`default_nettype none
`timescale 1ns/1ps

// Dual-edge triggered flip flop.

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
        p <= {DATA_WIDTH{1'b0}};
      else
        p <= dp ^ n;
   end

   always @(negedge clk) begin
      if (!rst_n)
        n <= {DATA_WIDTH{1'b0}};
      else
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
      if ($past(rst_n) && past_valid) begin
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
