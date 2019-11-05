`default_nettype none

module adc #(
   parameter DATA_WIDTH = 12
) (
   input wire                         clk_i,
   input wire                         ce_i,
   input wire signed [DATA_WIDTH-1:0] data_i,
   output reg signed [DATA_WIDTH-1:0] chan_a,
   output reg signed [DATA_WIDTH-1:0] chan_b
);

   // I want both channels to send data on the falling clock edge,
   // that way subsequent modules can read them on the rising clock
   // edge. This requires a buffer for channel B which is normally
   // made available on the rising clock edge.
   reg signed [DATA_WIDTH-1:0]        chan_b_buf;

   initial begin
      chan_a     = {DATA_WIDTH{1'b0}};
      chan_b     = {DATA_WIDTH{1'b0}};
      chan_b_buf = {DATA_WIDTH{1'b0}};
   end

   always @(posedge clk_i) begin
      if (ce_i) begin
         chan_b_buf <= data_i;
      end else begin // if (ce_i)
         chan_b_buf <= {DATA_WIDTH{1'b0}};
      end // else: !if(ce_i)
   end

   always @(negedge clk_i) begin
      if (ce_i) begin
         chan_a <= data_i;
         chan_b <= chan_b_buf;
      end else begin // if (ce_i)
         chan_a <= {DATA_WIDTH{1'b0}};
         chan_b <= {DATA_WIDTH{1'b0}};
      end // else: !if(ce_i)
   end

endmodule // chan_split
