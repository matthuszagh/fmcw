`ifndef _WINDOW_V_
`define _WINDOW_V_

`default_nettype none
`timescale 1ns/1ps

module window #(
   parameter N           = 1024,
   parameter DATA_WIDTH  = 14,
   parameter COEFF_WIDTH = 16
) (
   input wire                         clk,
   input wire                         rst_n,
   input wire                         en,
   input wire                         clk_en,
   input wire signed [DATA_WIDTH-1:0] di,
   output reg                         dvalid,
   output reg signed [DATA_WIDTH-1:0] dout
);

   localparam INTERNAL_WIDTH = DATA_WIDTH + COEFF_WIDTH;
   /* verilator lint_off WIDTH */
   localparam [$clog2(N-1)-1:0] N_CMP = N - 1;
   /* verilator lint_on WIDTH */

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
   reg [$clog2(N)-1:0]                ctr;

   // TODO shouldn't use a full path
   initial begin
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/window/coeffs.hex", coeffs);
   end

   reg en_buf;
   always @(posedge clk) begin
      if (!rst_n) begin
         ctr <= {$clog2(N){1'b0}};
         {dvalid, en_buf} <= {1'b0, 1'b0};
      end else if (clk_en) begin
         {dvalid, en_buf} <= {en_buf, en};
         internal         <= di * $signed({1'b0, coeffs[ctr]});
         dout             <= trunc_to_out(round_convergent(internal));
         if (ctr == {$clog2(N){1'b0}}) begin
            if (en) begin
               ctr <= {{$clog2(N)-1{1'b0}}, 1'b1};
            end
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
