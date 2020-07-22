`ifndef _BIN2GRAY_V_
`define _BIN2GRAY_V_

`default_nettype none
`timescale 1ns/1ps

module bin2gray #(
   parameter WIDTH = 8
) (
   input wire [WIDTH-1:0]  bin,
   output wire [WIDTH-1:0] gray
);

   assign gray = (bin>>1) ^ bin;

endmodule
`endif
