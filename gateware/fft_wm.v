`ifndef _FFT_WM_V_
`define _FFT_WM_V_
`default_nettype none

module fft_wm #(
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

   localparam A_DATA_WIDTH = DATA_WIDTH;
   localparam B_DATA_WIDTH = TWIDDLE_WIDTH + 1;
   localparam C_DATA_WIDTH = DATA_WIDTH + TWIDDLE_WIDTH + 1;
   localparam P_DATA_WIDTH = DATA_WIDTH + TWIDDLE_WIDTH + 1;

   function [B_DATA_WIDTH-1:0] sign_extend_b(input [TWIDDLE_WIDTH-1:0] expr);
      sign_extend_b = (expr[TWIDDLE_WIDTH-1] == 1'b1) ? {{B_DATA_WIDTH-TWIDDLE_WIDTH{1'b1}}, expr}
                      : {{B_DATA_WIDTH-TWIDDLE_WIDTH{1'b0}}, expr};
   endfunction

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
   reg [1:0]                             mul_state;
   reg signed [DATA_WIDTH+TWIDDLE_WIDTH:0] kar_f;
   reg signed [DATA_WIDTH+TWIDDLE_WIDTH:0] kar_r;
   reg signed [DATA_WIDTH+TWIDDLE_WIDTH:0] kar_i;

   reg signed [DATA_WIDTH-1:0] x_re_reg;
   reg signed [DATA_WIDTH-1:0] x_im_reg;
   reg signed [DATA_WIDTH-1:0] x_re_reg2;
   reg signed [DATA_WIDTH-1:0] x_im_reg2;
   reg signed [TWIDDLE_WIDTH-1:0] w_re_reg;
   reg signed [TWIDDLE_WIDTH-1:0] w_im_reg;

   reg signed [DATA_WIDTH-1:0] a0_reg;
   reg signed [TWIDDLE_WIDTH:0] b0_reg;
   reg signed [DATA_WIDTH-1:0] a1_reg;
   reg signed [TWIDDLE_WIDTH:0] b1_reg;
   reg signed [DATA_WIDTH-1:0] a2_reg;
   reg signed [TWIDDLE_WIDTH:0] b2_reg;

   // `mul_state_start' ensures that `mul_state' is not dependent on
   // when `rst_n' is released.
   reg                            mul_state_start;
   always @(posedge clk_i) begin
      if (!rst_n)
        mul_state_start <= 1'b0;
      else
        mul_state_start <= 1'b1;
   end

   always @(posedge clk_3x_i) begin
      if (!mul_state_start) begin
         mul_state <= 2'd0;
      end else begin
         case (mul_state)
         2'd0:
           begin
              kar_r     <= p_dsp;
              mul_state <= 2'd1;

              a0_reg <= x_im_reg2;
              b0_reg <= w_re_reg - w_im_reg;
           end
         2'd1:
           begin
              kar_i     <= p_dsp;
              mul_state <= 2'd2;
              // updating the regs on `mul_state==2'd1' ensures that
              // `kar_i' is not set before `kar_f'.
              x_re_reg  <= x_re_i;
              x_re_reg2 <= x_re_reg;
              x_im_reg  <= x_im_i;
              x_im_reg2 <= x_im_reg;
              w_re_reg  <= w_re_i;
              w_im_reg  <= w_im_i;

              a1_reg <= x_re_reg2;
              b1_reg <= w_re_reg + w_im_reg;
           end
         2'd2:
           begin
              kar_f     <= p_dsp;
              mul_state <= 2'd0;

              a2_reg <= x_re_reg2 - x_im_reg2;
              b2_reg <= sign_extend_b(w_re_reg);
           end
         default:
           begin
              mul_state <= 2'd0;
           end
         endcase
      end
   end

   reg signed [DATA_WIDTH-1:0] a_dsp;
   reg signed [TWIDDLE_WIDTH:0] b_dsp;
   reg signed [DATA_WIDTH+TWIDDLE_WIDTH:0] c_dsp;
   wire signed [DATA_WIDTH+TWIDDLE_WIDTH:0] p_dsp;

   always @(*) begin
      case (mul_state)
      2'd0:
        begin
           a_dsp = a0_reg;
           b_dsp = b0_reg;
           c_dsp = kar_f;
        end
      2'd1:
        begin
           a_dsp = a1_reg;
           b_dsp = b1_reg;
           c_dsp = -kar_f;
        end
      2'd2:
        begin
           a_dsp = a2_reg;
           b_dsp = b2_reg;
           c_dsp = {DATA_WIDTH+TWIDDLE_WIDTH+1{1'b0}};
        end
      default:
        begin
           a_dsp = {DATA_WIDTH{1'b0}};
           b_dsp = {TWIDDLE_WIDTH+1{1'b0}};
           c_dsp = {DATA_WIDTH+TWIDDLE_WIDTH+1{1'b0}};
        end
      endcase
   end

   assign p_dsp = (a_dsp * b_dsp) + c_dsp;

   parameter INTERNAL_WIDTH = DATA_WIDTH+TWIDDLE_WIDTH;
   parameter INTERNAL_MIN_MSB = INTERNAL_WIDTH - 1;

   function [INTERNAL_MIN_MSB-1:0] drop_msb_bits(input [INTERNAL_WIDTH:0] expr);
      drop_msb_bits = expr[INTERNAL_MIN_MSB-1:0];
   endfunction

   function [INTERNAL_MIN_MSB-1:0] round_convergent(input [INTERNAL_MIN_MSB-1:0] expr);
      round_convergent = expr + {{DATA_WIDTH{1'b0}},
                                 expr[INTERNAL_MIN_MSB-DATA_WIDTH],
                                 {INTERNAL_MIN_MSB-DATA_WIDTH-1{!expr[INTERNAL_MIN_MSB-DATA_WIDTH]}}};
   endfunction

   function [DATA_WIDTH-1:0] trunc_to_out(input [INTERNAL_MIN_MSB-1:0] expr);
      trunc_to_out = expr[INTERNAL_MIN_MSB-1:INTERNAL_MIN_MSB-DATA_WIDTH];
   endfunction

   reg [NLOG2-1:0] ctr_reg;
   reg [NLOG2-1:0] ctr_reg2;
   reg [NLOG2-1:0] ctr_reg3;
   always @(posedge clk_i) begin
      if (!rst_n) begin
         ctr_reg  <= {NLOG2{1'b0}};
         ctr_reg2 <= {NLOG2{1'b0}};
         ctr_reg3 <= {NLOG2{1'b0}};
         ctr_o    <= {NLOG2{1'b0}};
      end else begin
         ctr_reg  <= ctr_i;
         ctr_reg2 <= ctr_reg;
         ctr_reg3 <= ctr_reg2;
         ctr_o    <= ctr_reg3;

         // TODO verify that dropping msb is ok

         // safe to ignore the msb since the greatest possible
         // absolute twiddle value is 2^(TWIDDLE_WIDTH-1)
         z_re_o   <= trunc_to_out(round_convergent(drop_msb_bits(kar_r)));
         z_im_o   <= trunc_to_out(round_convergent(drop_msb_bits(kar_i)));

         // simple truncation for comparison
         // z_re_o   <= kar_r[DATA_WIDTH+TWIDDLE_WIDTH-2:TWIDDLE_WIDTH-1];
         // z_im_o   <= kar_i[DATA_WIDTH+TWIDDLE_WIDTH-2:TWIDDLE_WIDTH-1];
      end
   end

endmodule
`endif
