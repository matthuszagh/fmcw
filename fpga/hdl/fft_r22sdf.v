`default_nettype none

`include "fmcw_defines.vh"
`include "fft_r22sdf_bf.v"
`include "fft_r22sdf_wm.v"

/** Radix-2^2 SDF FFT implementation.
 *
 * TODO this design has not been sufficiently generalized. Currently
 * it only works for N=1024. It should be redesigned to support any
 * power-of-2 length.
 *
 * TODO I currently use DW+8 for the internal bit precision then bit
 * shift by 8 to get the output precision the same as the input
 * precision. I'm not sure this is right and is worth investigating
 * further.
 */

module fft_r22sdf #( `FMCW_DEFAULT_PARAMS )
   (
    input wire                  clk_i,
    input wire                  ce_i, // input data ready
    output reg                  sync_o, // output data ready
    // freq bin index of output data. only valid if `sync_o == 1'b1'
    output wire [FFT_NLOG2-1:0] data_cnt,
    input wire signed [OW-1:0]  data_re_i,
    input wire signed [OW-1:0]  data_im_i,
    output reg signed [OW-1:0]  data_re_o,
    output reg signed [OW-1:0]  data_im_o
    );

   reg [FFT_NLOG2-1:0]         sample_cnt [0:2*FFT_STAGES-1];
   // non bit-reversed output data count
   reg [FFT_NLOG2-1:0]         data_cnt_bit_nrml;

   // twiddle factors
   reg signed [TWIDDLE_WIDTH-1:0] w_s0_re [0:FFT_N-1];
   reg signed [TWIDDLE_WIDTH-1:0] w_s0_im [0:FFT_N-1];
   reg signed [TWIDDLE_WIDTH-1:0] w_s1_re [0:FFT_N/4-1];
   reg signed [TWIDDLE_WIDTH-1:0] w_s1_im [0:FFT_N/4-1];
   reg signed [TWIDDLE_WIDTH-1:0] w_s2_re [0:FFT_N/16-1];
   reg signed [TWIDDLE_WIDTH-1:0] w_s2_im [0:FFT_N/16-1];
   reg signed [TWIDDLE_WIDTH-1:0] w_s3_re [0:FFT_N/64-1];
   reg signed [TWIDDLE_WIDTH-1:0] w_s3_im [0:FFT_N/64-1];

   // stage counters
   // provide control logic to each stage
   reg [FFT_NLOG2-1:0]            stage0_cnt;
   wire [FFT_NLOG2-1:0]           stage1_cnt_tmp;
   wire [FFT_NLOG2-1:0]           stage1_cnt;
   wire [FFT_NLOG2-1:0]           stage2_cnt_tmp;
   wire [FFT_NLOG2-1:0]           stage2_cnt;
   wire [FFT_NLOG2-1:0]           stage3_cnt_tmp;
   wire [FFT_NLOG2-1:0]           stage3_cnt;
   wire [FFT_NLOG2-1:0]           stage4_cnt_tmp;
   wire [FFT_NLOG2-1:0]           stage4_cnt;

   reg                     stage0_cnt_delay;

   // // output data comes out in bit-reversed order
   // assign data_cnt[0:FFT_NLOG2-1] = data_cnt_bit_nrml[FFT_NLOG2-1:0];

   integer                        fs0, fs1, fs2, fs3, i, r1, r2;
   integer                        res_re, res_im;
   initial begin
      stage0_cnt        = {FFT_NLOG2{1'b0}};
      stage0_cnt_delay  = 1'b0;
      data_cnt_bit_nrml = {FFT_NLOG2{1'b0}};
      sync_o            = 1'b0;
      data_re_o         = {OW{1'b0}};
      data_im_o         = {OW{1'b0}};

      for (i=0; i<2*FFT_STAGES; i=i+1) begin
         sample_cnt[i] = {FFT_NLOG2{1'b0}};
      end

      fs0 = $fopen("/home/matt/src/fmcw-radar/fpga/hdl/fft_r22sdf_rom_s0.hex", "rb");
      for (i=0; i<FFT_N; i=i+1) begin
         r1 = $fscanf(fs0, "%h", res_re);
         w_s0_re[i] = res_re[TWIDDLE_WIDTH-1:0];
         r2 = $fscanf(fs0, "%h", res_im);
         w_s0_im[i] = res_im[TWIDDLE_WIDTH-1:0];
      end

      fs1 = $fopen("/home/matt/src/fmcw-radar/fpga/hdl/fft_r22sdf_rom_s1.hex", "rb");
      for (i=0; i<FFT_N/4; i=i+1) begin
         r1 = $fscanf(fs1, "%h", res_re);
         w_s1_re[i] = res_re[TWIDDLE_WIDTH-1:0];
         r2 = $fscanf(fs1, "%h", res_im);
         w_s1_im[i] = res_im[TWIDDLE_WIDTH-1:0];
      end

      fs2 = $fopen("/home/matt/src/fmcw-radar/fpga/hdl/fft_r22sdf_rom_s2.hex", "rb");
      for (i=0; i<FFT_N/16; i=i+1) begin
         r1 = $fscanf(fs2, "%h", res_re);
         w_s2_re[i] = res_re[TWIDDLE_WIDTH-1:0];
         r2 = $fscanf(fs2, "%h", res_im);
         w_s2_im[i] = res_im[TWIDDLE_WIDTH-1:0];
      end

      fs3 = $fopen("/home/matt/src/fmcw-radar/fpga/hdl/fft_r22sdf_rom_s3.hex", "rb");
      for (i=0; i<FFT_N/64; i=i+1) begin
         r1 = $fscanf(fs3, "%h", res_re);
         w_s3_re[i] = res_re[TWIDDLE_WIDTH-1:0];
         r2 = $fscanf(fs3, "%h", res_im);
         w_s3_im[i] = res_im[TWIDDLE_WIDTH-1:0];
      end
   end

   // output data comes out in bit-reversed order
   genvar k;
   generate
      for (k=0; k<FFT_NLOG2; k=k+1) begin
         assign data_cnt[k] = data_cnt_bit_nrml[FFT_NLOG2-1-k];
      end
   endgenerate

   // stage 0
   wire signed [FFTDW-1:0] bf0_re;
   wire signed [FFTDW-1:0] bf0_im;
   wire signed [FFTDW-1:0] w0_re;
   wire signed [FFTDW-1:0] w0_im;

   fft_r22sdf_bf #(.DW        (FFTDW),
                   .FFT_N     (FFT_N),
                   .FFT_NLOG2 (FFT_NLOG2),
                   .STAGE     (0),
                   .STAGES    (FFT_STAGES))
   stage0_bf (.clk_i  (clk_i),
              .cnt_i  (stage0_cnt),
              // .cnt_o  (stage1_cnt_tmp),
              .cnt_o  (stage1_cnt),
              .x_re_i ($signed(data_re_i)),
              .x_im_i ($signed(data_im_i)),
              .z_re_o (bf0_re),
              .z_im_o (bf0_im));

   fft_r22sdf_wm #(.DW            (FFTDW),
                   .TWIDDLE_WIDTH (TWIDDLE_WIDTH),
                   .FFT_N         (FFT_N),
                   .NLOG2         (FFT_NLOG2))
   stage0_wm (.clk_i  (clk_i),
              // .ctr_i  (stage1_cnt_tmp),
              // .ctr_o  (stage1_cnt),
              .ce_i   (ce_i),
              .x_re_i (bf0_re),
              .x_im_i (bf0_im),
              // .w_re_i (stage0_cnt > 10'd766 ? w_s0_re[stage0_cnt - 10'd767] : 10'd1),
              // .w_im_i (stage0_cnt > 10'd766 ? w_s0_im[stage0_cnt - 10'd767] : 10'd0),
              .w_re_i (w_s0_re[stage1_cnt]),
              .w_im_i (w_s0_im[stage1_cnt]),
              .z_re_o (w0_re),
              .z_im_o (w0_im));

   // stage 1
   wire signed [FFTDW-1:0] bf1_re;
   wire signed [FFTDW-1:0] bf1_im;
   wire signed [FFTDW-1:0] w1_re;
   wire signed [FFTDW-1:0] w1_im;

   fft_r22sdf_bf #(.DW        (FFTDW),
                   .FFT_N     (FFT_N),
                   .FFT_NLOG2 (FFT_NLOG2),
                   .STAGE     (1),
                   .STAGES    (FFT_STAGES))
   stage1_bf (.clk_i  (clk_i),
              .cnt_i  (stage1_cnt),
              .cnt_o  (stage2_cnt),
              // .cnt_o  (stage2_cnt_tmp),
              .x_re_i (w0_re),
              .x_im_i (w0_im),
              .z_re_o (bf1_re),
              .z_im_o (bf1_im));

   fft_r22sdf_wm #(.DW            (FFTDW),
                   .TWIDDLE_WIDTH (TWIDDLE_WIDTH),
                   .FFT_N         (FFT_N),
                   .NLOG2         (FFT_NLOG2))
   stage1_wm (.clk_i  (clk_i),
              // .ctr_i  (stage2_cnt_tmp),
              // .ctr_o  (stage2_cnt),
              .ce_i   (ce_i),
              .x_re_i (bf1_re),
              .x_im_i (bf1_im),
              // .w_re_i (stage1_cnt[7:0] > 8'd191 ? w_s1_re[stage1_cnt[7:0] - 8'd191] : 10'd1),
              // .w_im_i (stage1_cnt[7:0] > 8'd191 ? w_s1_im[stage1_cnt[7:0] - 8'd191] : 10'd0),
              .w_re_i (w_s1_re[stage2_cnt[7:0]]),
              .w_im_i (w_s1_im[stage2_cnt[7:0]]),
              .z_re_o (w1_re),
              .z_im_o (w1_im));

   // stage 2
   wire signed [FFTDW-1:0] bf2_re;
   wire signed [FFTDW-1:0] bf2_im;
   wire signed [FFTDW-1:0] w2_re;
   wire signed [FFTDW-1:0] w2_im;

   fft_r22sdf_bf #(.DW        (FFTDW),
                   .FFT_N     (FFT_N),
                   .FFT_NLOG2 (FFT_NLOG2),
                   .STAGE     (2),
                   .STAGES    (FFT_STAGES))
   stage2_bf (.clk_i  (clk_i),
              .cnt_i  (stage2_cnt),
              .cnt_o  (stage3_cnt),
              // .cnt_o  (stage3_cnt_tmp),
              .x_re_i (w1_re),
              .x_im_i (w1_im),
              .z_re_o (bf2_re),
              .z_im_o (bf2_im));

   fft_r22sdf_wm #(.DW            (FFTDW),
                   .TWIDDLE_WIDTH (TWIDDLE_WIDTH),
                   .FFT_N         (FFT_N),
                   .NLOG2         (FFT_NLOG2))
   stage2_wm (.clk_i  (clk_i),
              // .ctr_i  (stage3_cnt_tmp),
              // .ctr_o  (stage3_cnt),
              .ce_i   (ce_i),
              .x_re_i (bf2_re),
              .x_im_i (bf2_im),
              // .w_re_i (stage2_cnt[5:0] > 6'd47 ? w_s2_re[stage2_cnt[5:0] - 6'd47] : 10'd1),
              // .w_im_i (stage2_cnt[5:0] > 6'd47 ? w_s2_im[stage2_cnt[5:0] - 6'd47] : 10'd0),
              .w_re_i (w_s2_re[stage3_cnt[5:0]]),
              .w_im_i (w_s2_im[stage3_cnt[5:0]]),
              .z_re_o (w2_re),
              .z_im_o (w2_im));

   // stage 3
   wire signed [FFTDW-1:0] bf3_re;
   wire signed [FFTDW-1:0] bf3_im;
   wire signed [FFTDW-1:0] w3_re;
   wire signed [FFTDW-1:0] w3_im;

   fft_r22sdf_bf #(.DW        (FFTDW),
                   .FFT_N     (FFT_N),
                   .FFT_NLOG2 (FFT_NLOG2),
                   .STAGE     (3),
                   .STAGES    (FFT_STAGES))
   stage3_bf (.clk_i  (clk_i),
              .cnt_i  (stage3_cnt),
              .cnt_o  (stage4_cnt),
              // .cnt_o  (stage4_cnt_tmp),
              .x_re_i (w2_re),
              .x_im_i (w2_im),
              .z_re_o (bf3_re),
              .z_im_o (bf3_im));

   fft_r22sdf_wm #(.DW            (FFTDW),
                   .TWIDDLE_WIDTH (TWIDDLE_WIDTH),
                   .FFT_N         (FFT_N),
                   .NLOG2         (FFT_NLOG2))
   stage3_wm (.clk_i  (clk_i),
              // .ctr_i  (stage4_cnt_tmp),
              // .ctr_o  (stage4_cnt),
              .ce_i   (ce_i),
              .x_re_i (bf3_re),
              .x_im_i (bf3_im),
              // .w_re_i (stage3_cnt[3:0] > 4'd11 ? w_s3_re[stage3_cnt[3:0] - 4'd11] : 10'd1),
              // .w_im_i (stage3_cnt[3:0] > 4'd11 ? w_s3_im[stage3_cnt[3:0] - 4'd11] : 10'd0),
              .w_re_i (w_s3_re[stage4_cnt[3:0]]),
              .w_im_i (w_s3_im[stage4_cnt[3:0]]),
              .z_re_o (w3_re),
              .z_im_o (w3_im));

   // stage 4
   wire signed [FFTDW-1:0] bf4_re;
   wire signed [FFTDW-1:0] bf4_im;

   fft_r22sdf_bf #(.DW        (FFTDW),
                   .FFT_N     (FFT_N),
                   .FFT_NLOG2 (FFT_NLOG2),
                   .STAGE     (4),
                   .STAGES    (FFT_STAGES))
   stage4_bf (.clk_i  (clk_i),
              .cnt_i  (stage4_cnt),
              .x_re_i (w3_re),
              .x_im_i (w3_im),
              .z_re_o (bf4_re),
              .z_im_o (bf4_im));

   always @(posedge clk_i) begin
      if (ce_i) begin
         data_re_o <= bf4_re >>> FFTDW-OW;
         data_im_o <= bf4_im >>> FFTDW-OW;
         // stage0_cnt_delay <= 1'b1;
         // if (stage0_cnt_delay) begin
         //    stage0_cnt <= stage0_cnt + 1'b1;
         // end else begin
         //    stage0_cnt <= {FFT_NLOG2{1'b0}};
         // end
         stage0_cnt <= stage0_cnt + 1'b1;

         if (sync_o == 1'b1) begin
            data_cnt_bit_nrml <= data_cnt_bit_nrml + 1'b1;
         end else begin
            data_cnt_bit_nrml <= {FFT_NLOG2{1'b0}};
         end

         if (stage0_cnt == 10'd1023 || sync_o == 1'b1) begin
            sync_o <= 1'b1;
         end else begin
            sync_o <= 1'b0;
         end
      end else begin // if (ce_i)
         stage0_cnt_delay  <= 1'b0;
         stage0_cnt        <= {FFT_NLOG2{1'b0}};
         data_cnt_bit_nrml <= {FFT_NLOG2{1'b0}};
         sync_o            <= 1'b0;
      end // else: !if(ce_i)
   end // always @ (posedge clk_i)

   // assign data_re_o = bf4_re >>> FFTDW-OW;
   // assign data_im_o = bf4_im >>> FFTDW-OW;

endmodule // fft_r22sdf
