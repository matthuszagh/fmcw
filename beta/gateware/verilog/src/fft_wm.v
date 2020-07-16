`ifndef _FFT_WM_V_
`define _FFT_WM_V_

`default_nettype none
`timescale 1ns/1ps

module fft_wm #(
   parameter WIDTH         = 24,
   parameter TWIDDLE_WIDTH = 18,
   parameter N             = 1024
) (
   input wire                            clk,
   input wire                            srst_n,
   input wire                            carry_in,
   output wire                           carry_out,
   input wire [$clog2(N)-1:0]            ctr_i,
   output wire [$clog2(N)-1:0]           ctr_o,
   input wire signed [WIDTH-1:0]         x_re_i,
   input wire signed [WIDTH-1:0]         x_im_i,
   input wire signed [TWIDDLE_WIDTH-1:0] w_re_i,
   input wire signed [TWIDDLE_WIDTH-1:0] w_im_i,
   output reg signed [WIDTH-1:0]         z_re_o,
   output reg signed [WIDTH-1:0]         z_im_o
);

   localparam INTERNAL_WIDTH = WIDTH + TWIDDLE_WIDTH;

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
   reg signed [INTERNAL_WIDTH-1:0] kar_f;
   reg signed [INTERNAL_WIDTH-1:0] kar_r;
   reg signed [INTERNAL_WIDTH-1:0] kar_i;

   localparam XSR_LEN = 2;
   reg signed [WIDTH-1:0]         x_re_sr [0:XSR_LEN-1];
   reg signed [WIDTH-1:0]         x_im_sr [0:XSR_LEN-1];
   reg signed [TWIDDLE_WIDTH-1:0] w_re_sr [0:XSR_LEN-2];
   reg signed [TWIDDLE_WIDTH-1:0] w_im_sr [0:XSR_LEN-2];
   localparam LATENCY = 4;
   integer i;

   always @(posedge clk) begin
      x_re_sr[0] <= x_re_i;
      x_im_sr[0] <= x_im_i;
      for (i=1; i<XSR_LEN; i=i+1) begin
         x_re_sr[i] <= x_re_sr[i-1];
         x_im_sr[i] <= x_im_sr[i-1];
      end

      w_re_sr[0] <= w_re_i;
      w_im_sr[0] <= w_im_i;
      for (i=1; i<XSR_LEN-1; i=i+1) begin
         w_re_sr[i] <= w_re_sr[i-1];
         w_im_sr[i] <= w_im_sr[i-1];
      end

      kar_f <= w_re_i * (x_re_sr[0] - x_im_sr[0]);
      kar_r <= x_im_sr[1] * (w_re_sr[0] - w_im_sr[0]) + kar_f;
      kar_i <= x_re_sr[1] * (w_re_sr[0] + w_im_sr[0]) - kar_f;
   end

   localparam INTERNAL_MIN_MSB = INTERNAL_WIDTH - 1;

   function [INTERNAL_MIN_MSB-1:0] drop_msb_bits(input [INTERNAL_WIDTH-1:0] expr);
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

   reg [$clog2(N)-1:0] ctr_shift_reg [0:LATENCY-1];
   reg carry_shift_reg [0:LATENCY-1];

   initial for (i=0; i<LATENCY; i=i+1) carry_shift_reg[i] = 1'b0;
   always @(posedge clk) begin
      if (~srst_n) begin
         for (i=0; i<LATENCY; i=i+1) carry_shift_reg[i] <= 1'b0;
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
      z_re_o <= trunc_to_out(round_convergent(drop_msb_bits(kar_r)));
      z_im_o <= trunc_to_out(round_convergent(drop_msb_bits(kar_i)));

      // simple truncation for comparison
      // z_re_o <= kar_r[WIDTH+TWIDDLE_WIDTH-2:TWIDDLE_WIDTH-1];
      // z_im_o <= kar_i[WIDTH+TWIDDLE_WIDTH-2:TWIDDLE_WIDTH-1];
   end
   assign ctr_o = ctr_shift_reg[LATENCY-1];

endmodule
`endif
