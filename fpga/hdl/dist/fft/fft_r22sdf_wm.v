`default_nettype none

`include "mult_add.v"

module fft_r22sdf_wm #(
   parameter DATA_WIDTH    = 25,
   parameter TWIDDLE_WIDTH = 10,
   parameter FFT_N         = 1024,
   parameter NLOG2         = 10
) (
   input wire                            clk_i,
   input wire                            rst_n,
   input wire                            clk_3x_i,
   input wire [NLOG2-1:0]                ctr_i,
   output reg [NLOG2-1:0]                ctr_o,
   input wire signed [DATA_WIDTH-1:0]    x_re_i,
   input wire signed [DATA_WIDTH-1:0]    x_im_i,
   input wire signed [TWIDDLE_WIDTH-1:0] w_re_i,
   input wire signed [TWIDDLE_WIDTH-1:0] w_im_i,
   output reg signed [DATA_WIDTH-1:0]    z_re_o,
   output reg signed [DATA_WIDTH-1:0]    z_im_o
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
   reg [1:0]                                 mul_state;
   reg signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] kar_f;
   reg signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] kar_r;
   reg signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] kar_i;

   reg signed [DATA_WIDTH-1:0] x_re_reg;
   reg signed [DATA_WIDTH-1:0] x_im_reg;
   reg signed [DATA_WIDTH-1:0] x_re_reg2;
   reg signed [DATA_WIDTH-1:0] x_im_reg2;
   reg signed [TWIDDLE_WIDTH-1:0] w_re_reg;
   reg signed [TWIDDLE_WIDTH-1:0] w_im_reg;
   always @(posedge clk_3x_i) begin
      if (!rst_n) begin
         kar_f     <= {DATA_WIDTH+TWIDDLE_WIDTH{1'b0}};
         kar_r     <= {DATA_WIDTH+TWIDDLE_WIDTH{1'b0}};
         kar_i     <= {DATA_WIDTH+TWIDDLE_WIDTH{1'b0}};
         mul_state <= 2'd0;
         x_re_reg  <= {DATA_WIDTH{1'b0}};
         x_im_reg  <= {DATA_WIDTH{1'b0}};
         x_re_reg2 <= {DATA_WIDTH{1'b0}};
         x_im_reg2 <= {DATA_WIDTH{1'b0}};
      end else begin
         case (mul_state)
         2'd0:
           begin
              kar_f     <= p_dsp;
              mul_state <= 2'd1;
           end
         2'd1:
           begin
              kar_r     <= p_dsp;
              mul_state <= 2'd2;
           end
         2'd2:
           begin
              kar_i     <= p_dsp;
              mul_state <= 2'd0;
              x_re_reg  <= x_re_i;
              x_im_reg  <= x_im_i;
              x_re_reg2 <= x_re_reg;
              x_im_reg2 <= x_im_reg;
              w_re_reg  <= w_re_i;
              w_im_reg  <= w_im_i;
           end
         endcase
      end
   end

   reg signed [DATA_WIDTH-1:0] a_dsp;
   reg signed [TWIDDLE_WIDTH:0] b_dsp;
   reg signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] c_dsp;
   wire signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] p_dsp;

   always @(*) begin
      case (mul_state)
      2'd0:
        begin
           a_dsp = x_re_reg2 - x_im_reg2;
           b_dsp = w_re_reg;
           c_dsp = {DATA_WIDTH+TWIDDLE_WIDTH{1'b0}};
        end
      2'd1:
        begin
           a_dsp = x_im_reg2;
           b_dsp = w_re_reg - w_im_reg;
           c_dsp = kar_f;
        end
      2'd2:
        begin
           a_dsp = x_re_reg2;
           b_dsp = w_re_reg + w_im_reg;
           c_dsp = -kar_f;
        end
      default:
        begin
           a_dsp = {DATA_WIDTH{1'b0}};
           b_dsp = {TWIDDLE_WIDTH+1{1'b0}};
           c_dsp = {DATA_WIDTH+TWIDDLE_WIDTH{1'b0}};
        end
      endcase
   end

   mult_add #(
      .A_DATA_WIDTH (DATA_WIDTH),
      .B_DATA_WIDTH (TWIDDLE_WIDTH+1),
      .C_DATA_WIDTH (DATA_WIDTH+TWIDDLE_WIDTH),
      .P_DATA_WIDTH (DATA_WIDTH+TWIDDLE_WIDTH)
   ) twiddle_multiply (
      .a (a_dsp),
      .b (b_dsp),
      .c (c_dsp),
      .p (p_dsp)
   );

   reg [NLOG2-1:0] ctr_reg;
   reg [NLOG2-1:0] ctr_reg2;
   always @(posedge clk_i) begin
      if (!rst_n) begin
         ctr_o    <= {NLOG2{1'b0}};
         z_re_o   <= {DATA_WIDTH{1'b0}};
         z_im_o   <= {DATA_WIDTH{1'b0}};
      end else begin
         ctr_reg  <= ctr_i;
         ctr_reg2 <= ctr_reg;
         ctr_o    <= ctr_reg2;

         // TODO does this cause rounding error? see the zipcpu blog
         // post about rounding.

         // TODO verify that dropping msb is ok

         // safe to ignore the msb since the greatest possible
         // absolute twiddle value is 2^(TWIDDLE_WIDTH-1)
         z_re_o   <= kar_r[DATA_WIDTH+TWIDDLE_WIDTH-2:TWIDDLE_WIDTH-1];
         z_im_o   <= kar_i[DATA_WIDTH+TWIDDLE_WIDTH-2:TWIDDLE_WIDTH-1];
      end
   end

endmodule
// Local Variables:
// flycheck-verilator-include-path:("/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unimacro/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unisims/"
//                                  "/home/matt/src/libdigital/libdigital/hdl/dsp/multiply_add/")
// End:
