`ifndef _FFT_BFI_V_
`define _FFT_BFI_V_

`default_nettype none
`timescale 1ns/1ps

`include "shift_reg.v"

module fft_bfi #(
   parameter WIDTH         = 24,
   parameter SHIFT_REG_LEN = 512
) (
   input wire                    clk,
   input wire                    srst_n,
   input wire                    carry_in,
   output wire                   carry_out,
   input wire                    sel_i,
   input wire signed [WIDTH-1:0] x_re_i,
   input wire signed [WIDTH-1:0] x_im_i,
   output reg signed [WIDTH-1:0] z_re_o,
   output reg signed [WIDTH-1:0] z_im_o
);

   wire signed [WIDTH-1:0]       sr_re;
   wire signed [WIDTH-1:0]       sr_im;
   wire signed [WIDTH-1:0]       xsr_re;
   wire signed [WIDTH-1:0]       xsr_im;
   reg signed [WIDTH-1:0]        zsr_re;
   reg signed [WIDTH-1:0]        zsr_im;

   assign xsr_re = sr_re;
   assign xsr_im = sr_im;

   always @(*) begin
      if (sel_i) begin
         z_re_o = x_re_i + xsr_re;
         z_im_o = x_im_i + xsr_im;

         zsr_re = xsr_re - x_re_i;
         zsr_im = xsr_im - x_im_i;
      end else begin
         z_re_o = xsr_re;
         z_im_o = xsr_im;

         zsr_re = x_re_i;
         zsr_im = x_im_i;
      end
   end

   integer i;
   generate
      if (SHIFT_REG_LEN > 1) begin
         shift_reg #(
            .WIDTH (WIDTH         ),
            .LEN   (SHIFT_REG_LEN )
         ) shift_reg_re (
            .clk    (clk    ),
            .di     (zsr_re ),
            .data_o (sr_re  )
         );

         shift_reg #(
            .WIDTH (WIDTH         ),
            .LEN   (SHIFT_REG_LEN )
         ) shift_reg_im (
            .clk    (clk    ),
            .di     (zsr_im ),
            .data_o (sr_im  )
         );
      end else begin
         reg signed [WIDTH-1:0] sr_re_reg [0:SHIFT_REG_LEN-1];
         reg signed [WIDTH-1:0] sr_im_reg [0:SHIFT_REG_LEN-1];

         always @(posedge clk) begin
            sr_re_reg[0] <= zsr_re;
            sr_im_reg[0] <= zsr_im;
            for (i=1; i<SHIFT_REG_LEN; i=i+1) begin
               sr_re_reg[i] <= sr_re_reg[i-1];
               sr_im_reg[i] <= sr_im_reg[i-1];
            end
         end
         assign sr_re = sr_re_reg[SHIFT_REG_LEN-1];
         assign sr_im = sr_im_reg[SHIFT_REG_LEN-1];
      end
   endgenerate

   reg carry [0:SHIFT_REG_LEN-1];
   initial for (i=0; i<SHIFT_REG_LEN; i=i+1) carry[i] = 1'b0;
   always @(posedge clk) begin
      if (~srst_n) begin
         for (i=0; i<SHIFT_REG_LEN; i=i+1) carry[i] <= 1'b0;
      end else begin
         carry[0] <= carry_in;
         for (i=1; i<SHIFT_REG_LEN; i=i+1) carry[i] <= carry[i-1];
      end
   end
   assign carry_out = carry[SHIFT_REG_LEN-1];

endmodule
`endif
