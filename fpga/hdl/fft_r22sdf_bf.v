`default_nettype none

`include "fft_r22sdf_bfi.v"
`include "fft_r22sdf_bfii.v"

module fft_r22sdf_bf #(
                       parameter DW = 24,
                       parameter FFT_N = 1024,
                       parameter FFT_NLOG2 = 10,
                       parameter STAGE = 0,
                       parameter STAGES = 0
                       )
   (
    input wire                 clk_i,
    input wire [FFT_NLOG2-1:0] cnt_i,
    output reg [FFT_NLOG2-1:0] cnt_o,
    input wire [DW-1:0]        x_re_i,
    input wire [DW-1:0]        x_im_i,
    output wire [DW-1:0]       z_re_o,
    output wire [DW-1:0]       z_im_o
    );

   wire                        sel1;
   wire                        sel2;
   reg [FFT_NLOG2-1:0]         ctrii;
   // wire [FFT_NLOG2-1:0]        ctrii_shift = ctrii + 1'b1;
   reg                         start_ctrii;
   reg                         start_ctr_o;

   wire signed [DW-1:0]  z_re;
   wire signed [DW-1:0]  z_im;

   // assign sel1 = (cnt_i[FFT_NLOG2-1-2*STAGE:0] > FFT_N/2**(2*STAGE+1)-1) ? 1'b1 : 1'b0;
   // assign sel2 = (ctrii[FFT_NLOG2-2-2*STAGE:0] > FFT_N/2**(2*STAGE+2)-1) ? 1'b1 : 1'b0;
   assign sel1 = cnt_i[FFT_NLOG2-1-2*STAGE];
   assign sel2 = ctrii[FFT_NLOG2-2-2*STAGE];

   initial begin
      cnt_o       = {FFT_NLOG2{1'b0}};
      ctrii       = {FFT_NLOG2{1'b0}};
      start_ctrii = 1'b0;
      start_ctr_o = 1'b0;
   end

   fft_r22sdf_bfi #(.DW      (DW),
                    .FSR_LEN (2**(2*(STAGES-STAGE)-1)))
   bfi (.clk_i  (clk_i),
        .sel_i  (sel1),
        .x_re_i (x_re_i),
        .x_im_i (x_im_i),
        .z_re_o (z_re),
        .z_im_o (z_im));

   fft_r22sdf_bfii #(.DW      (DW),
                     .FSR_LEN (2**(2*(STAGES-STAGE)-2)))
   bfii (.clk_i  (clk_i),
         .sel_i  (sel2),
         .tsel_i (sel1),
         .x_re_i (z_re),
         .x_im_i (z_im),
         .z_re_o (z_re_o),
         .z_im_o (z_im_o));

   always @(posedge sel1) begin
      start_ctrii <= 1'b1;
   end
   always @(posedge sel2) begin
      start_ctr_o <= 1'b1;
   end

   always @(posedge clk_i) begin
      if (sel1 || start_ctrii) begin
         ctrii <= ctrii + 1'b1;
      end else begin
         ctrii <= {FFT_NLOG2{1'b0}};
      end

      if (sel2 || start_ctr_o) begin
         cnt_o <= cnt_o + 1'b1;
      end
      else begin
         cnt_o <= {FFT_NLOG2{1'b0}};
      end
   end

endmodule // butterfly
