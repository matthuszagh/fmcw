`ifndef _FFT_BF_V_
`define _FFT_BF_V_
`default_nettype none

`include "fft_bfi.v"
`include "fft_bfii.v"

module fft_bf #(
   parameter DATA_WIDTH = 25,
   parameter FFT_N      = 1024,
   parameter FFT_NLOG2  = 10,
   parameter STAGE      = 0,
   parameter STAGES     = 5
) (
   input wire                          clk_i,
   input wire                          rst_n,
   input wire [FFT_NLOG2-1:0]          cnt_i,
   output reg [FFT_NLOG2-1:0]          cnt_o,
   input wire signed [DATA_WIDTH-1:0]  x_re_i,
   input wire signed [DATA_WIDTH-1:0]  x_im_i,
   output wire signed [DATA_WIDTH-1:0] z_re_o,
   output wire signed [DATA_WIDTH-1:0] z_im_o
);

   wire                       sel1;
   wire                       sel2;
   reg [FFT_NLOG2-1:0]        ctrii;
   reg                        start_ctrii;
   reg                        start_ctr_o;

   wire signed [DATA_WIDTH-1:0]  z_re;
   wire signed [DATA_WIDTH-1:0]  z_im;

   assign sel1 = cnt_i[FFT_NLOG2-1-2*STAGE];
   assign sel2 = ctrii[FFT_NLOG2-2-2*STAGE];

   fft_bfi #(
      .DATA_WIDTH    (DATA_WIDTH              ),
      .SHIFT_REG_LEN (2**(2*(STAGES-STAGE)-1) )
   ) bfi (
      .clk_i  (clk_i  ),
      .rst_n  (rst_n  ),
      .sel_i  (sel1   ),
      .x_re_i (x_re_i ),
      .x_im_i (x_im_i ),
      .z_re_o (z_re   ),
      .z_im_o (z_im   )
   );

   fft_bfii #(
      .DATA_WIDTH    (DATA_WIDTH              ),
      .SHIFT_REG_LEN (2**(2*(STAGES-STAGE)-2) )
   ) bfii (
      .clk_i  (clk_i  ),
      .rst_n  (rst_n  ),
      .sel_i  (sel2   ),
      .tsel_i (sel1   ),
      .x_re_i (z_re   ),
      .x_im_i (z_im   ),
      .z_re_o (z_re_o ),
      .z_im_o (z_im_o )
   );

   always @(posedge clk_i) begin
      if (!rst_n) begin
         start_ctrii <= 1'b0;
         ctrii       <= {FFT_NLOG2{1'b0}};
         start_ctr_o <= 1'b0;
         cnt_o       <= {FFT_NLOG2{1'b0}};
      end else begin
         if (sel1)
           start_ctrii <= 1'b1;

         if (sel1 || start_ctrii)
           ctrii <= ctrii + 1'b1;

         if (sel2)
           start_ctr_o <= 1'b1;

         if (sel2 || start_ctr_o)
           cnt_o <= cnt_o + 1'b1;
      end
   end

endmodule
`endif
