`ifndef _PLL_SYNC_CTR_V_
`define _PLL_SYNC_CTR_V_

`default_nettype none
`timescale 1ns/1ps

`include "dual_ff.v"

module pll_sync_ctr #(
   /* ratio of slow clock period to fast clock period */
   parameter RATIO = 8
) (
   input wire                     fst_clk,
   input wire                     slw_clk,
   input wire                     rst_n,
   output reg [$clog2(RATIO)-1:0] ctr
);

   localparam [$clog2(RATIO)-1:0] RATIO_CMP = RATIO[$clog2(RATIO)-1:0];

   wire                           slw_clk_tmp;
   reg                            last_slw_clk;

   // Dual edge-triggered flip-flop.
   dual_ff #(
      .DATA_WIDTH (1)
   ) dual_ff (
      .clk   (slw_clk     ),
      .rst_n (rst_n       ),
      .dp    (1'b1        ),
      .dn    (1'b0        ),
      .q     (slw_clk_tmp )
   );

   always @(posedge fst_clk) begin
      last_slw_clk <= slw_clk_tmp;
      if (!last_slw_clk && slw_clk_tmp) begin
         ctr <= {{$clog2(RATIO)-1{1'b0}}, 1'b1};
      end else begin
         if (ctr == RATIO_CMP-1'b1)
           ctr <= {$clog2(RATIO){1'b0}};
         else
           ctr <= ctr + 1'b1;
      end
   end

`ifdef COCOTB_SIM
   initial begin
      $dumpfile ("cocotb/build/pll_sync_ctr.vcd");
      $dumpvars (0, pll_sync_ctr);
      #1;
   end
`endif

endmodule
`endif
