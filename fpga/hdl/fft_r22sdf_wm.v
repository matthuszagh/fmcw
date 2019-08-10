`default_nettype none

module fft_r22sdf_wm #(
                       parameter DW = 24,
                       parameter TWIDDLE_WIDTH = 10,
                       parameter FFT_N = 1024,
                       parameter NLOG2 = 10
                       )
   (
    input wire                            clk_i,
    input wire                            ce_i,
    input wire [NLOG2-1:0]                ctr_i,
    output reg [NLOG2-1:0]                ctr_o,
    input wire signed [DW-1:0]            x_re_i,
    input wire signed [DW-1:0]            x_im_i,
    input wire signed [TWIDDLE_WIDTH-1:0] w_re_i,
    input wire signed [TWIDDLE_WIDTH-1:0] w_im_i,
    output reg signed [DW-1:0]            z_re_o,
    output reg signed [DW-1:0]            z_im_o
    );

   initial begin
      z_re_o = {DW{1'b0}};
      z_im_o = {DW{1'b0}};
      ctr_o  = {NLOG2{1'b0}};
   end

   /**
    * Use the karatsuba algorithm to conserve multiplies.
    *
    * R+iI = (a+ib) * (c+id)
    *
    * e = a-b
    * f = c*e
    * R = b(c-d)+f
    * I = a(c+d)-f
    */
   wire [DW+TWIDDLE_WIDTH-1:0] kar_f;
   wire [DW+TWIDDLE_WIDTH-1:0] kar_r;
   wire [DW+TWIDDLE_WIDTH-1:0] kar_i;

   assign kar_f = $signed(w_re_i) * ($signed(x_re_i) - $signed(x_im_i));
   assign kar_r = $signed(x_im_i) * ($signed(w_re_i) - $signed(w_im_i)) + $signed(kar_f);
   assign kar_i = $signed(x_re_i) * ($signed(w_re_i) + $signed(w_im_i)) - $signed(kar_f);

   always @(posedge clk_i) begin
      ctr_o <= ctr_i;
      if (ce_i) begin
         z_re_o <= kar_r >>> (TWIDDLE_WIDTH-1);
         z_im_o <= kar_i >>> (TWIDDLE_WIDTH-1);
      end
      else begin
         z_re_o <= z_re_o;
         z_im_o <= z_im_o;
      end // else: !if(ce_i)
   end

endmodule // fft_sdf_tfm
