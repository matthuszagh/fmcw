`default_nettype none

module decimate #(
   parameter M    = 20,
   parameter M_LG = 5,
   parameter DW   = 16
) (
   input wire                 clk_i,
   input wire                 clk_2mhz_pos_en_i,
   input wire                 ce_i,
   input wire signed [DW-1:0] di_i,
   output reg signed [DW-1:0] do_o = {DW{1'b0}}
);

   reg [M_LG-1:0]             ctr = {M_LG{1'b0}};

   always @(posedge clk_i) begin
      if (ce_i) begin
         if (ctr == M-1) begin
            ctr <= {M_LG{1'b0}};
         end else begin
            ctr <= ctr + 1'b1;
         end
      end else begin
         ctr   <= {M_LG{1'b0}};
      end
   end

   always @(posedge clk_i) begin
      if (ce_i) begin
         if (clk_2mhz_pos_en_i) begin
            do_o <= di_i;
         end else begin
            do_o <= do_o;
         end
      end else begin
         do_o <= {DW{1'b0}};
      end
   end

endmodule // decimate
