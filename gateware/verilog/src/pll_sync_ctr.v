`ifndef _PLL_SYNC_CTR_V_
`define _PLL_SYNC_CTR_V_

`default_nettype none
`timescale 1ns/1ps

`include "dual_ff.v"

// Generates a counter reflecting the phase relationship between 2
// synchronous clocks with different frequencies. Specifically, when
// the positive clock edge of the slow clock triggers, the counter
// will be set to 0 and will increment every fast clock period until
// the next slow clock edge.
module pll_sync_ctr #(
   // ratio of slow clock period to fast clock period
   parameter RATIO = 8
) (
   input wire                     fst_clk,
   input wire                     slw_clk,
   output reg [$clog2(RATIO)-1:0] ctr = {$clog2(RATIO){1'b0}}
);

   localparam [$clog2(RATIO)-1:0] RATIO_MAX = RATIO-1;

   wire                           slw_clk_tmp;
   reg                            last_slw_clk = 1'b0;

   dual_ff #(
      .WIDTH (1)
   ) dual_ff (
      .clk   (slw_clk     ),
      .dp    (1'b1        ),
      .dn    (1'b0        ),
      .q     (slw_clk_tmp )
   );

   always @(posedge fst_clk) begin
      last_slw_clk <= slw_clk_tmp;
      if (~last_slw_clk & slw_clk_tmp) begin
         ctr <= {{$clog2(RATIO)-1{1'b0}}, 1'b1};
      end else begin
         if (ctr == RATIO_MAX)
           ctr <= {$clog2(RATIO){1'b0}};
         else
           ctr <= ctr + 1'b1;
      end
   end

`ifdef FORMAL
 `ifdef PLL_SYNC_CTR
  `define ASSUME assume
 `else
  `define ASSUME assert
 `endif

   (* gclk *) reg gclk;
   integer gctr                       = 0;
   reg [$clog2(RATIO)-1:0] out_ctr    = 0;
   reg                     past_valid = 0;
   always @(posedge gclk) begin
      gctr <= gctr + 1;
      past_valid <= 1;
      if ($initstate) begin
         `ASSUME (fst_clk == 1'b0);
         `ASSUME (slw_clk == 1'b0);
      end else begin
         `ASSUME ($changed(fst_clk));
         if (gctr == 0) begin
            `ASSUME (slw_clk == 1);
         end
      end

      if (past_valid) begin
         if ($past(out_ctr) == 7 & $rose(fst_clk)) begin
            `ASSUME ($changed(slw_clk));
         end else begin
            `ASSUME ($stable(slw_clk));
         end

         if ($rose(slw_clk)) begin
            assert (ctr == 0);
         end
      end

      if (past_valid) begin
         assert (out_ctr == ctr);
      end
   end

   always @(posedge fst_clk) begin
      out_ctr <= out_ctr + 1'b1;
   end

`endif

`ifdef COCOTB_SIM
 `ifdef PLL_SYNC_CTR
   initial begin
      $dumpfile ("cocotb/build/pll_sync_ctr.vcd");
      $dumpvars (0, pll_sync_ctr);
      #1;
   end
 `endif
`endif

endmodule
`endif
