`default_nettype none

module fft_r22sdf_wm #(
   parameter DW            = 25,
   parameter TWIDDLE_WIDTH = 10,
   parameter FFT_N         = 1024,
   parameter NLOG2         = 10
) (
   input wire                            clk_i,
   input wire                            clk_3x_i,
   input wire                            ce_i,
   input wire [NLOG2-1:0]                ctr_i,
   output reg [NLOG2-1:0]                ctr_o = {NLOG2{1'b0}},
   input wire signed [DW-1:0]            x_re_i,
   input wire signed [DW-1:0]            x_im_i,
   input wire signed [TWIDDLE_WIDTH-1:0] w_re_i,
   input wire signed [TWIDDLE_WIDTH-1:0] w_im_i,
   output reg signed [DW-1:0]            z_re_o = {DW{1'b0}},
   output reg signed [DW-1:0]            z_im_o = {DW{1'b0}}
);

   /**
    * Use the karatsuba algorithm to use 3 multiplies instead of 4.
    *
    * R+iI = (a+ib) * (c+id)
    *
    * e = a-b
    * f = c*e
    * R = b(c-d)+f
    * I = a(c+d)-f
    */
   // compute multiplies in stages to share DSP.
   reg [1:0] mul_state = 2'd0;
   reg signed [DW+TWIDDLE_WIDTH-1:0] kar_f = {DW+TWIDDLE_WIDTH{1'b0}};
   reg signed [DW+TWIDDLE_WIDTH-1:0] kar_r = {DW+TWIDDLE_WIDTH{1'b0}};
   reg signed [DW+TWIDDLE_WIDTH-1:0] kar_i = {DW+TWIDDLE_WIDTH{1'b0}};

   always @(posedge clk_3x_i) begin
      if (ce_i) begin
         case (mul_state)
         2'd0:
           begin
              kar_f     <= w_re_i * (x_re_i - x_im_i);
              kar_r     <= kar_r;
              kar_i     <= kar_i;
              mul_state <= 2'd1;
           end
         2'd1:
           begin
              kar_f     <= kar_f;
              kar_r     <= x_im_i * (w_re_i - w_im_i) + kar_f;
              kar_i     <= kar_i;
              mul_state <= 2'd2;
           end
         2'd2:
           begin
              kar_f     <= kar_f;
              kar_r     <= kar_r;
              kar_i     <= x_re_i * (w_re_i + w_im_i) - kar_f;
              mul_state <= 2'd0;
           end
         default:
           begin
              kar_f     <= {DW+TWIDDLE_WIDTH{1'b0}};
              kar_r     <= {DW+TWIDDLE_WIDTH{1'b0}};
              kar_i     <= {DW+TWIDDLE_WIDTH{1'b0}};
              mul_state <= 2'd0;
           end
         endcase // case (mul_state)
      end else begin
         kar_f     <= {DW+TWIDDLE_WIDTH{1'b0}};
         kar_r     <= {DW+TWIDDLE_WIDTH{1'b0}};
         kar_i     <= {DW+TWIDDLE_WIDTH{1'b0}};
         mul_state <= 2'd0;
      end
   end

   always @(posedge clk_i) begin
      ctr_o <= ctr_i;
      if (ce_i) begin
         // TODO does this cause rounding error? see the zipcpu blog
         // post about rounding.

         // TODO verify that dropping msb is ok

         // safe to ignore the msb since the greatest possible
         // absolute twiddle value is 2^(TWIDDLE_WIDTH-1)
         z_re_o <= kar_r[DW+TWIDDLE_WIDTH-2:TWIDDLE_WIDTH-1];
         z_im_o <= kar_i[DW+TWIDDLE_WIDTH-2:TWIDDLE_WIDTH-1];
      end
   end

endmodule // fft_sdf_tfm
