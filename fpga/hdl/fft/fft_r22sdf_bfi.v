`default_nettype none

module fft_r22sdf_bfi #(
   parameter DW      = 25,
   parameter FSR_LEN = 0
) (
   input wire                 clk_i,
   input wire                 sel_i,
   input wire signed [DW-1:0] x_re_i,
   input wire signed [DW-1:0] x_im_i,
   output reg signed [DW-1:0] z_re_o = {DW{1'b0}},
   output reg signed [DW-1:0] z_im_o = {DW{1'b0}}
);

   // TODO change fsr to sr. There is no feedback!

   // shift register
   reg signed [DW-1:0]        fsr_re [0:FSR_LEN-1];
   reg signed [DW-1:0]        fsr_im [0:FSR_LEN-1];

   integer                    i;
   initial begin
      for (i=0; i<FSR_LEN; i=i+1) begin
         fsr_re[i] = {DW{1'b0}};
         fsr_im[i] = {DW{1'b0}};
      end
   end

   wire signed [DW-1:0]        xfsr_re;
   wire signed [DW-1:0]        xfsr_im;
   reg signed [DW-1:0]         zfsr_re = {DW{1'b0}};
   reg signed [DW-1:0]         zfsr_im = {DW{1'b0}};

   assign xfsr_re = fsr_re[FSR_LEN-1];
   assign xfsr_im = fsr_im[FSR_LEN-1];

   always @(*) begin
      if (sel_i) begin
         z_re_o  = x_re_i + xfsr_re;
         z_im_o  = x_im_i + xfsr_im;
         zfsr_re = xfsr_re - x_re_i;
         zfsr_im = xfsr_im - x_im_i;
      end else begin
         z_re_o  = xfsr_re;
         z_im_o  = xfsr_im;
         zfsr_re = x_re_i;
         zfsr_im = x_im_i;
      end
   end

   always @(posedge clk_i) begin
      fsr_re[0] <= zfsr_re;
      fsr_im[0] <= zfsr_im;
      for (i=1; i<FSR_LEN; i=i+1) begin
         fsr_re[i] <= fsr_re[i-1];
         fsr_im[i] <= fsr_im[i-1];
      end
   end

endmodule // fft_r22sdf
