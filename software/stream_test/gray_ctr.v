`ifndef _GRAY_CTR_V_
`define _GRAY_CTR_V_

`default_nettype none
`timescale 1ns/1ps

`include "bin2gray.v"

module gray_ctr #(
   parameter WIDTH = 8
) (
   input wire              inc,
   input wire              clk,
   input wire              rst_n,
   output reg [WIDTH-1:0]  gray,
   output wire [WIDTH-1:0] gray_next,
   output wire [WIDTH-2:0] bin
);

   reg [WIDTH-1:0]         bin_int;
   wire [WIDTH-1:0]        bin_next = bin_int + inc;

   assign bin = bin_int[WIDTH-2:0];

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         bin_int <= {WIDTH{1'b0}};
         gray <= {WIDTH{1'b0}};
      end else begin
         bin_int <= bin_next;
         gray    <= gray_next;
      end
   end

   bin2gray #(
      .WIDTH (WIDTH)
   ) bin2gray (
      .bin  (bin_next  ),
      .gray (gray_next )
   );

endmodule
`endif
