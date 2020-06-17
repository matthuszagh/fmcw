`ifndef _CLK_ENABLE_V_
`define _CLK_ENABLE_V_

`default_nettype none
`timescale 1ns/1ps

// Generate clock enable signals to be able to use clocks below the
// minimum PLL frequency. This module also outputs a counter that
// increments with the base clock and starts at 0 at the slow clock
// edge.

module clk_enable #(
   // Value by which to divide the base clock frequency to determine
   // the slow clock frequency.
   parameter DIVIDE = 0
) (
   input wire                      clk_base,
   input wire                      rst_n,
   output reg                      clk_enable,
   output reg [$clog2(DIVIDE)-1:0] ctr
);

   localparam [$clog2(DIVIDE)-1:0] DIVIDE_MAX = DIVIDE - 1;

   always @(posedge clk_base) begin
      if (!rst_n) begin
         ctr <= {$clog2(DIVIDE){1'b0}};
      end else begin
         if (ctr == DIVIDE_MAX) begin
            clk_enable <= 1'b1;
            ctr        <= {$clog2(DIVIDE){1'b0}};
         end else begin
            clk_enable <= 1'b0;
            ctr        <= ctr + 1'b1;
         end
      end
   end

endmodule
`endif
