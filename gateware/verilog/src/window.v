`ifndef _WINDOW_V_
`define _WINDOW_V_

`default_nettype none
`timescale 1ns/1ps

`include "ff_sync.v"

module window #(
   parameter N           = 1024,
   parameter DATA_WIDTH  = 14,
   parameter COEFF_WIDTH = 16
) (
   input wire                         clk,
   input wire                         arst_n,
   input wire                         en,
   input wire                         clk_en,
   input wire signed [DATA_WIDTH-1:0] di,
   output wire                        dvalid,
   output reg signed [DATA_WIDTH-1:0] dout
);

   localparam INTERNAL_WIDTH = DATA_WIDTH + COEFF_WIDTH;
   /* verilator lint_off WIDTH */
   localparam [$clog2(N)-1:0] N_CMP = N - 1;
   /* verilator lint_on WIDTH */

   wire                               srst_n;
   ff_sync #(
      .WIDTH  (1),
      .STAGES (2)
   ) rst_sync (
      .dest_clk (clk    ),
      .d        (arst_n ),
      .q        (srst_n )
   );

   function [INTERNAL_WIDTH-1:0] round_convergent(input [INTERNAL_WIDTH-1:0] expr);
      round_convergent = expr + {{DATA_WIDTH{1'b0}},
                                 expr[INTERNAL_WIDTH-DATA_WIDTH],
                                 {INTERNAL_WIDTH-DATA_WIDTH-1{!expr[INTERNAL_WIDTH-DATA_WIDTH]}}};
   endfunction

   function [DATA_WIDTH-1:0] trunc_to_out(input [INTERNAL_WIDTH-1:0] expr);
      trunc_to_out = expr[INTERNAL_WIDTH-1:INTERNAL_WIDTH-DATA_WIDTH];
   endfunction

   reg signed [INTERNAL_WIDTH-1:0]    internal;
   reg [COEFF_WIDTH-1:0]              coeffs [0:N-1];
   reg [$clog2(N)-1:0]                ctr = {$clog2(N){1'b0}};

   // TODO shouldn't use a full path
   initial begin
      $readmemh("/home/matt/src/fmcw/gateware/verilog/src/roms/window/coeffs.hex", coeffs);
   end

   localparam LATENCY = 2;
   integer i;
   reg valid_sync [0:LATENCY-1];
   initial for (i=0; i<LATENCY; i=i+1) valid_sync[i] = 1'b0;

   always @(posedge clk) begin
      if (~srst_n) begin
         for (i=0; i<LATENCY; i=i+1) valid_sync[i] <= 1'b0;
      end else begin
         if (clk_en) begin
            valid_sync[0] <= en;
            for (i=1; i<LATENCY; i=i+1) valid_sync[i] <= valid_sync[i-1];
         end
      end
   end
   assign dvalid = valid_sync[LATENCY-1];

   always @(posedge clk) begin
      if (clk_en) begin
         internal <= di * $signed({1'b0, coeffs[ctr]});
         dout     <= trunc_to_out(round_convergent(internal));
         if (ctr == {$clog2(N){1'b0}}) begin
            if (en) ctr <= {{$clog2(N)-1{1'b0}}, 1'b1};
         end else begin
            if (ctr == N_CMP) begin
               ctr <= {$clog2(N){1'b0}};
            end else begin
               ctr <= ctr + 1'b1;
            end
         end
      end
   end

`ifdef COCOTB_SIM
   `ifdef WINDOW
   integer i;
   initial begin
      $dumpfile ("cocotb/build/window.vcd");
      $dumpvars (0, window);
      for (i=0; i<100; i=i+1)
        $dumpvars (0, coeffs[i]);
      #1;
   end
   `endif
`endif

endmodule
`endif
