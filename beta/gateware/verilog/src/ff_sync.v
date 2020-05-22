`ifndef _FF_SYNC_V_
`define _FF_SYNC_V_

`default_nettype none
`timescale 1ns/1ps

module ff_sync #(
   parameter WIDTH  = 8,
   parameter STAGES = 2
) (
   input wire              dest_clk,
   input wire [WIDTH-1:0]  d,
   output wire [WIDTH-1:0] q
);

   (* ASYNC_REG = "TRUE" *)
   reg [WIDTH-1:0]         sync [0:1];

   initial begin
      sync[0] = 0;
      sync[1] = 0;
   end

   // reg [WIDTH-1:0]         sync [0:STAGES-1];

   // genvar                  i;
   // generate
   //    for (i=0; i<STAGES-1; i=i+1) begin
   //       always @(posedge dest_clk) begin
   //          sync[i+1][WIDTH-1:0] <= sync[i][WIDTH-1:0];
   //       end
   //    end
   // endgenerate

   always @(posedge dest_clk) begin
      {sync[1], sync[0]} <= {sync[0], d};
   end

   // assign q = sync[STAGES-1];
   assign q = sync[1];

endmodule
`endif
