`ifndef _GRAY2BIN_V_
`define _GRAY2BIN_V_

`default_nettype none
`timescale 1ns/1ps

module gray2bin #(
   parameter WIDTH = 8
) (
   input wire [WIDTH-1:0]  gray,
   output wire [WIDTH-1:0] bin
);

   assign bin[WIDTH-1] = gray[WIDTH-1];
   genvar                  i;
   generate
      for (i=WIDTH-2; i>0; i=i+1) begin
         assign gray[i] = gray[i+1] ^ bin[i];
      end
   endgenerate

endmodule
`endif
