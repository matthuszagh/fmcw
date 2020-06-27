`ifndef _FFT_WM_V_
`define _FFT_WM_V_

`default_nettype none
`timescale 1ns/1ps

`include "pll_sync_ctr.v"

module fft_wm #(
   parameter WIDTH         = 25,
   parameter TWIDDLE_WIDTH = 10,
   parameter N             = 1024
) (
   input wire                            clk,
   input wire                            srst_n,
   input wire                            carry_in,
   output wire                           carry_out,
   input wire                            clk_3x,
   input wire [$clog2(N)-1:0]            ctr_i,
   output wire [$clog2(N)-1:0]           ctr_o,
   input wire signed [WIDTH-1:0]         x_re_i,
   input wire signed [WIDTH-1:0]         x_im_i,
   input wire signed [TWIDDLE_WIDTH-1:0] w_re_i,
   input wire signed [TWIDDLE_WIDTH-1:0] w_im_i,
   output reg signed [WIDTH-1:0]         z_re_o,
   output reg signed [WIDTH-1:0]         z_im_o
);

   localparam A_WIDTH = WIDTH;
   localparam B_WIDTH = TWIDDLE_WIDTH + 1;
   localparam C_WIDTH = WIDTH + TWIDDLE_WIDTH + 1;
   localparam P_WIDTH = WIDTH + TWIDDLE_WIDTH + 1;

   function [B_WIDTH-1:0] sign_extend_b(input [TWIDDLE_WIDTH-1:0] expr);
      sign_extend_b = (expr[TWIDDLE_WIDTH-1] == 1'b1) ? {{B_WIDTH-TWIDDLE_WIDTH{1'b1}}, expr}
                      : {{B_WIDTH-TWIDDLE_WIDTH{1'b0}}, expr};
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
   reg signed [WIDTH+TWIDDLE_WIDTH:0] kar_f;
   reg signed [WIDTH+TWIDDLE_WIDTH:0] kar_r;
   reg signed [WIDTH+TWIDDLE_WIDTH:0] kar_i;

   reg signed [WIDTH-1:0]             x_re_reg;
   reg signed [WIDTH-1:0]             x_im_reg;
   reg signed [WIDTH-1:0]             x_re_reg2;
   reg signed [WIDTH-1:0]             x_im_reg2;
   reg signed [TWIDDLE_WIDTH-1:0]     w_re_reg;
   reg signed [TWIDDLE_WIDTH-1:0]     w_im_reg;

   reg signed [WIDTH-1:0]             a0_reg;
   reg signed [TWIDDLE_WIDTH:0]       b0_reg;
   reg signed [WIDTH-1:0]             a1_reg;
   reg signed [TWIDDLE_WIDTH:0]       b1_reg;
   reg signed [WIDTH-1:0]             a2_reg;
   reg signed [TWIDDLE_WIDTH:0]       b2_reg;

   wire [1:0]                         mul_state;
   pll_sync_ctr #(
      .RATIO (3)
   ) sync_ctr (
      .fst_clk (clk_3x    ),
      .slw_clk (clk       ),
      .ctr     (mul_state )
   );

   always @(posedge clk_3x) begin
      case (mul_state)
      2'd0:
        begin
           kar_r  <= p_dsp;
           a0_reg <= x_im_reg2;
           b0_reg <= w_re_reg - w_im_reg;
        end
      2'd1:
        begin
           kar_i     <= p_dsp;
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
           kar_f  <= p_dsp;
           a2_reg <= x_re_reg2 - x_im_reg2;
           b2_reg <= sign_extend_b(w_re_reg);
        end
      // d'd3 is unreachable, as long as pll_sync_ctr works
      endcase
   end

   reg signed [WIDTH-1:0]              a_dsp;
   reg signed [TWIDDLE_WIDTH:0]        b_dsp;
   reg signed [WIDTH+TWIDDLE_WIDTH:0]  c_dsp;
   wire signed [WIDTH+TWIDDLE_WIDTH:0] p_dsp;

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
           c_dsp = {WIDTH+TWIDDLE_WIDTH+1{1'b0}};
        end
      default:
        begin
           a_dsp = {WIDTH{1'b0}};
           b_dsp = {TWIDDLE_WIDTH+1{1'b0}};
           c_dsp = {WIDTH+TWIDDLE_WIDTH+1{1'b0}};
        end
      endcase
   end

   assign p_dsp = (a_dsp * b_dsp) + c_dsp;

   parameter INTERNAL_WIDTH = WIDTH+TWIDDLE_WIDTH;
   parameter INTERNAL_MIN_MSB = INTERNAL_WIDTH - 1;

   function [INTERNAL_MIN_MSB-1:0] drop_msb_bits(input [INTERNAL_WIDTH:0] expr);
      drop_msb_bits = expr[INTERNAL_MIN_MSB-1:0];
   endfunction

   function [INTERNAL_MIN_MSB-1:0] round_convergent(input [INTERNAL_MIN_MSB-1:0] expr);
      round_convergent = expr + {{WIDTH{1'b0}},
                                 expr[INTERNAL_MIN_MSB-WIDTH],
                                 {INTERNAL_MIN_MSB-WIDTH-1{!expr[INTERNAL_MIN_MSB-WIDTH]}}};
   endfunction

   function [WIDTH-1:0] trunc_to_out(input [INTERNAL_MIN_MSB-1:0] expr);
      trunc_to_out = expr[INTERNAL_MIN_MSB-1:INTERNAL_MIN_MSB-WIDTH];
   endfunction

   localparam LATENCY = 4;
   integer i;
   reg [$clog2(N)-1:0] ctr_shift_reg [0:LATENCY-1];
   reg [$clog2(N)-1:0] carry_shift_reg [0:LATENCY-1];

   initial begin
      for (i=0; i<LATENCY; i=i+1) carry_shift_reg[i] <= {$clog2(N){1'b0}};
   end
   always @(posedge clk) begin
      if (~srst_n) begin
         for (i=0; i<LATENCY; i=i+1) carry_shift_reg[i] <= {$clog2(N){1'b0}};
      end else begin
         carry_shift_reg[0] <= carry_in;
         for (i=0; i<LATENCY-1; i=i+1) carry_shift_reg[i+1] <= carry_shift_reg[i];
      end
   end
   assign carry_out = carry_shift_reg[LATENCY-1];

   always @(posedge clk) begin
      ctr_shift_reg[0] <= ctr_i;
      for (i=0; i<LATENCY-1; i=i+1) ctr_shift_reg[i+1] <= ctr_shift_reg[i];

      // safe to ignore the msb since the greatest possible
      // absolute twiddle value is 2^(TWIDDLE_WIDTH-1)
      z_re_o   <= trunc_to_out(round_convergent(drop_msb_bits(kar_r)));
      z_im_o   <= trunc_to_out(round_convergent(drop_msb_bits(kar_i)));

      // simple truncation for comparison
      // z_re_o   <= kar_r[WIDTH+TWIDDLE_WIDTH-2:TWIDDLE_WIDTH-1];
      // z_im_o   <= kar_i[WIDTH+TWIDDLE_WIDTH-2:TWIDDLE_WIDTH-1];
   end
   assign ctr_o = ctr_shift_reg[LATENCY-1];

endmodule
`endif
