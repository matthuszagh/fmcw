`ifndef _FF_SYNC_V_
`define _FF_SYNC_V_

`default_nettype none
`timescale 1ns/1ps

module ff_sync #(
   parameter WIDTH  = 1,
   parameter STAGES = 2
) (
   input wire              dest_clk,
   input wire [WIDTH-1:0]  d,
   output wire [WIDTH-1:0] q
);

   (* ASYNC_REG = "TRUE" *)
   reg [WIDTH-1:0]         sync [0:STAGES-1];

   always @(posedge dest_clk) begin
      sync[0] <= d;
   end

   genvar                  i;
   generate
      for (i=0; i<STAGES-1; i=i+1) begin
         always @(posedge dest_clk) begin
            sync[i+1] <= sync[i];
         end
      end
   endgenerate

   assign q = sync[STAGES-1];

endmodule
`endif

`ifdef FF_SYNC_SIMULATE
module ff_sync_tb;

   localparam WIDTH  = 8;
   localparam STAGES = 3;

   reg clk40 = 1'b0;
   initial begin
      forever #12.5 clk40 = ~clk40;
   end

   initial begin
      $dumpfile("tb/ff_sync_tb.vcd");
      $dumpvars(0, ff_sync_tb);
      #10000 $finish;
   end

   reg [WIDTH-1:0] ctr = {WIDTH{1'b0}};
   always @(posedge clk40) begin
      ctr <= ctr + 1'b1;
   end

   wire [WIDTH-1:0] sync_out;
   ff_sync #(
      .WIDTH  (WIDTH  ),
      .STAGES (STAGES )
   ) dut (
      .dest_clk (clk40    ),
      .d        (ctr      ),
      .q        (sync_out )
   );

endmodule
`endif
