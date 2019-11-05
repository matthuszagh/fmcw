`default_nettype none

module usb #(
   parameter DATA_WIDTH = 8
) (
   inout wire [DATA_WIDTH-1:0] data_io,
   input wire [DATA_WIDTH-1:0] wdata_i,
   input wire             send_data_i, /* signals available data to send */
   input wire             txe_n_i,
   output reg             wr_n_o = 1'b1, /* pull low to send data to PC */
   input wire             clk_60mhz_i
);

   always @(negedge clk_60mhz_i) begin
      if (send_data_i) begin
         wr_n_o <= 1'b0;
      end else begin
         wr_n_o <= 1'b1;
      end
   end

   assign data_io = (!txe_n_i && !wr_n_o) ? wdata_i : {DATA_WIDTH{1'bz}};

endmodule // usb
