`ifndef _LTC2292_V_
`define _LTC2292_V_
`default_nettype none

// Simple interface for the LTC2292 ADC.

// TODO this module currently only supports a multiplexed output bus
// in full-range 2s complement mode. See the datasheet for details and
// other modes.

module ltc2292 #(
   parameter MUX = "TRUE"
) (
   input wire        clk,
   input wire [11:0] di,
   output reg [11:0] dao,
   output reg [11:0] dbo
);

   // TODO verify this is correct. It's not clear, and Henrik does it
   // the other way. When the ADC outputs are multiplexed, channel A
   // should be sampled on the clock's falling edge and channel B
   // sampled on the clock's rising edge.

   reg [11:0] dbuf;

   always @(posedge clk) begin
      dao <= dbuf;
      dbo <= di;
   end

   always @(negedge clk) begin
      dbuf <= di;
   end

endmodule
`endif
