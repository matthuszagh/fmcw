`default_nettype none

`include "fft_r22sdf_bf.v"
`include "fft_r22sdf_wm.v"

/** Radix-2^2 SDF FFT implementation.
 *
 * N must be a power of 4. Currently, any power of 4 <= 1024 is
 * supported, but this could easily be extended to greater lengths.
 */

module fft_r22sdf #(
   parameter N              = 1024, /* FFT length */
   parameter N_LOG2         = 10,
   parameter N_STAGES       = 5,    /* log_4(N) */
   parameter INPUT_WIDTH    = 14,
   parameter TWIDDLE_WIDTH  = 10,
   // +1 comes from complex multiply, which is really 2 multiplies.
   parameter INTERNAL_WIDTH = 25,   /* ceil(log_2(N)) + INPUT_WIDTH + 1 */
   // output width is the same as internal width because we shift by
   // the twiddle bit width as we go.
   parameter OUTPUT_WIDTH   = 25
) (
   input wire                           clk_i,
   input wire                           clk_3x_i,
   input wire                           ce_i, // input data ready
   output reg                           sync_o = 1'b0, // output data ready
   // freq bin index of output data. only valid if `sync_o == 1'b1'
   output wire [N_LOG2-1:0]             data_ctr_o,
   input wire signed [INPUT_WIDTH-1:0]  data_re_i,
   input wire signed [INPUT_WIDTH-1:0]  data_im_i,
   output reg signed [OUTPUT_WIDTH-1:0] data_re_o = {OUTPUT_WIDTH{1'b0}},
   output reg signed [OUTPUT_WIDTH-1:0] data_im_o = {OUTPUT_WIDTH{1'b0}}
   );

   // non bit-reversed output data count
   reg [N_LOG2-1:0]                     data_ctr_bit_nrml = {N_LOG2{1'b0}};

   // twiddle factors
   reg signed [TWIDDLE_WIDTH-1:0]       w_s0_re [0:N-1];
   reg signed [TWIDDLE_WIDTH-1:0]       w_s0_im [0:N-1];
   reg signed [TWIDDLE_WIDTH-1:0]       w_s1_re [0:N/4-1];
   reg signed [TWIDDLE_WIDTH-1:0]       w_s1_im [0:N/4-1];
   reg signed [TWIDDLE_WIDTH-1:0]       w_s2_re [0:N/16-1];
   reg signed [TWIDDLE_WIDTH-1:0]       w_s2_im [0:N/16-1];
   reg signed [TWIDDLE_WIDTH-1:0]       w_s3_re [0:N/64-1];
   reg signed [TWIDDLE_WIDTH-1:0]       w_s3_im [0:N/64-1];

   // stage counters
   // provide control logic to each stage
   reg [N_LOG2-1:0]                     stage0_ctr = {N_LOG2{1'b0}};
   wire [N_LOG2-1:0]                    stage1_ctr_wm;
   wire [N_LOG2-1:0]                    stage1_ctr;
   wire [N_LOG2-1:0]                    stage2_ctr_wm;
   wire [N_LOG2-1:0]                    stage2_ctr;
   wire [N_LOG2-1:0]                    stage3_ctr_wm;
   wire [N_LOG2-1:0]                    stage3_ctr;
   wire [N_LOG2-1:0]                    stage4_ctr_wm;
   wire [N_LOG2-1:0]                    stage4_ctr;

   initial begin
      $readmemh("fft_r22sdf_rom_s0_re.hex", w_s0_re);
      $readmemh("fft_r22sdf_rom_s0_im.hex", w_s0_im);
      $readmemh("fft_r22sdf_rom_s1_re.hex", w_s1_re);
      $readmemh("fft_r22sdf_rom_s1_im.hex", w_s1_im);
      $readmemh("fft_r22sdf_rom_s2_re.hex", w_s2_re);
      $readmemh("fft_r22sdf_rom_s2_im.hex", w_s2_im);
      $readmemh("fft_r22sdf_rom_s3_re.hex", w_s3_re);
      $readmemh("fft_r22sdf_rom_s3_im.hex", w_s3_im);
   end

   // function [OUTPUT_WIDTH-1:0] trunc_to_output(input [INTERNAL_WIDTH-1:0] expr);
   //    trunc_to_output = expr[OUTPUT_WIDTH-1:0];
   // endfunction // trunc_to_output

   // output data comes out in bit-reversed order
   genvar k;
   generate
      for (k=0; k<N_LOG2; k=k+1) begin
         assign data_ctr_o[k] = data_ctr_bit_nrml[N_LOG2-1-k];
      end
   endgenerate

   // stage 0
   wire signed [INTERNAL_WIDTH-1:0] bf0_re;
   wire signed [INTERNAL_WIDTH-1:0] bf0_im;
   wire signed [INTERNAL_WIDTH-1:0] w0_re;
   wire signed [INTERNAL_WIDTH-1:0] w0_im;

   fft_r22sdf_bf #(
      .DW        (INTERNAL_WIDTH),
      .FFT_N     (N),
      .FFT_NLOG2 (N_LOG2),
      .STAGE     (0),
      .STAGES    (N_STAGES)
   ) stage0_bf (
      .clk_i  (clk_i),
      .cnt_i  (stage0_ctr),
      .cnt_o  (stage1_ctr_wm),
      .x_re_i (data_re_i),
      .x_im_i (data_im_i),
      .z_re_o (bf0_re),
      .z_im_o (bf0_im)
   );

   // stage 1
   wire signed [INTERNAL_WIDTH-1:0] bf1_re;
   wire signed [INTERNAL_WIDTH-1:0] bf1_im;
   wire signed [INTERNAL_WIDTH-1:0] w1_re;
   wire signed [INTERNAL_WIDTH-1:0] w1_im;

   generate
      if (N_STAGES > 1) begin
         fft_r22sdf_wm #(
            .DW            (INTERNAL_WIDTH),
            .TWIDDLE_WIDTH (TWIDDLE_WIDTH),
            .FFT_N         (N),
            .NLOG2         (N_LOG2)
         ) stage0_wm (
            .clk_i    (clk_i),
            .clk_3x_i (clk_3x_i),
            .ctr_i    (stage1_ctr_wm),
            .ctr_o    (stage1_ctr),
            .ce_i     (ce_i),
            .x_re_i   (bf0_re),
            .x_im_i   (bf0_im),
            .w_re_i   (w_s0_re[stage1_ctr_wm]),
            .w_im_i   (w_s0_im[stage1_ctr_wm]),
            .z_re_o   (w0_re),
            .z_im_o   (w0_im)
         );

         fft_r22sdf_bf #(
            .DW        (INTERNAL_WIDTH),
            .FFT_N     (N),
            .FFT_NLOG2 (N_LOG2),
            .STAGE     (1),
            .STAGES    (N_STAGES)
         ) stage1_bf (
            .clk_i  (clk_i),
            .cnt_i  (stage1_ctr),
            .cnt_o  (stage2_ctr_wm),
            .x_re_i (w0_re),
            .x_im_i (w0_im),
            .z_re_o (bf1_re),
            .z_im_o (bf1_im)
         );
      end // if (N > 1)
   endgenerate

   // stage 2
   wire signed [INTERNAL_WIDTH-1:0] bf2_re;
   wire signed [INTERNAL_WIDTH-1:0] bf2_im;
   wire signed [INTERNAL_WIDTH-1:0] w2_re;
   wire signed [INTERNAL_WIDTH-1:0] w2_im;

   generate
      if (N_STAGES > 2) begin
         fft_r22sdf_wm #(
            .DW            (INTERNAL_WIDTH),
            .TWIDDLE_WIDTH (TWIDDLE_WIDTH),
            .FFT_N         (N),
            .NLOG2         (N_LOG2)
         ) stage1_wm (
            .clk_i    (clk_i),
            .clk_3x_i (clk_3x_i),
            .ctr_i    (stage2_ctr_wm),
            .ctr_o    (stage2_ctr),
            .ce_i     (ce_i),
            .x_re_i   (bf1_re),
            .x_im_i   (bf1_im),
            .w_re_i   (w_s1_re[stage2_ctr_wm[7:0]]),
            .w_im_i   (w_s1_im[stage2_ctr_wm[7:0]]),
            .z_re_o   (w1_re),
            .z_im_o   (w1_im)
         );

         fft_r22sdf_bf #(
            .DW        (INTERNAL_WIDTH),
            .FFT_N     (N),
            .FFT_NLOG2 (N_LOG2),
            .STAGE     (2),
            .STAGES    (N_STAGES)
         ) stage2_bf (
            .clk_i  (clk_i),
            .cnt_i  (stage2_ctr),
            .cnt_o  (stage3_ctr_wm),
            .x_re_i (w1_re),
            .x_im_i (w1_im),
            .z_re_o (bf2_re),
            .z_im_o (bf2_im)
         );
      end // if (N > 2)
   endgenerate

   // stage 3
   wire signed [INTERNAL_WIDTH-1:0] bf3_re;
   wire signed [INTERNAL_WIDTH-1:0] bf3_im;
   wire signed [INTERNAL_WIDTH-1:0] w3_re;
   wire signed [INTERNAL_WIDTH-1:0] w3_im;

   generate
      if (N_STAGES > 3) begin
         fft_r22sdf_wm #(
            .DW            (INTERNAL_WIDTH),
            .TWIDDLE_WIDTH (TWIDDLE_WIDTH),
            .FFT_N         (N),
            .NLOG2         (N_LOG2)
         ) stage2_wm (
            .clk_i    (clk_i),
            .clk_3x_i (clk_3x_i),
            .ctr_i    (stage3_ctr_wm),
            .ctr_o    (stage3_ctr),
            .ce_i     (ce_i),
            .x_re_i   (bf2_re),
            .x_im_i   (bf2_im),
            .w_re_i   (w_s2_re[stage3_ctr_wm[5:0]]),
            .w_im_i   (w_s2_im[stage3_ctr_wm[5:0]]),
            .z_re_o   (w2_re),
            .z_im_o   (w2_im)
         );

         fft_r22sdf_bf #(
            .DW        (INTERNAL_WIDTH),
            .FFT_N     (N),
            .FFT_NLOG2 (N_LOG2),
            .STAGE     (3),
            .STAGES    (N_STAGES)
         ) stage3_bf (
            .clk_i  (clk_i),
            .cnt_i  (stage3_ctr),
            .cnt_o  (stage4_ctr_wm),
            .x_re_i (w2_re),
            .x_im_i (w2_im),
            .z_re_o (bf3_re),
            .z_im_o (bf3_im)
         );
      end // if (N > 3)
   endgenerate

   // stage 4
   wire signed [INTERNAL_WIDTH-1:0] bf4_re;
   wire signed [INTERNAL_WIDTH-1:0] bf4_im;

   generate
      if (N_STAGES > 4) begin
         fft_r22sdf_wm #(
            .DW            (INTERNAL_WIDTH),
            .TWIDDLE_WIDTH (TWIDDLE_WIDTH),
            .FFT_N         (N),
            .NLOG2         (N_LOG2)
         ) stage3_wm (
            .clk_i    (clk_i),
            .clk_3x_i (clk_3x_i),
            .ctr_i    (stage4_ctr_wm),
            .ctr_o    (stage4_ctr),
            .ce_i     (ce_i),
            .x_re_i   (bf3_re),
            .x_im_i   (bf3_im),
            .w_re_i   (w_s3_re[stage4_ctr_wm[3:0]]),
            .w_im_i   (w_s3_im[stage4_ctr_wm[3:0]]),
            .z_re_o   (w3_re),
            .z_im_o   (w3_im)
         );

         fft_r22sdf_bf #(
            .DW        (INTERNAL_WIDTH),
            .FFT_N     (N),
            .FFT_NLOG2 (N_LOG2),
            .STAGE     (4),
            .STAGES    (N_STAGES)
         ) stage4_bf (
            .clk_i  (clk_i),
            .cnt_i  (stage4_ctr),
            .x_re_i (w3_re),
            .x_im_i (w3_im),
            .z_re_o (bf4_re),
            .z_im_o (bf4_im)
         );
      end // if (N > 4)
   endgenerate

   wire signed [INTERNAL_WIDTH-1:0] data_bf_last_re;
   wire signed [INTERNAL_WIDTH-1:0] data_bf_last_im;

   generate
      case (N_STAGES)
      5:
        begin
           assign data_bf_last_re = bf4_re;
           assign data_bf_last_im = bf4_im;
        end
      4:
        begin
           assign data_bf_last_re = bf3_re;
           assign data_bf_last_im = bf3_im;
        end
      3:
        begin
           assign data_bf_last_re = bf2_re;
           assign data_bf_last_im = bf2_im;
        end
      2:
        begin
           assign data_bf_last_re = bf1_re;
           assign data_bf_last_im = bf1_im;
        end
      1:
        begin
           assign data_bf_last_re = bf0_re;
           assign data_bf_last_im = bf0_im;
        end
      endcase
   endgenerate

   always @(posedge clk_i) begin
      if (ce_i) begin
         data_re_o <= data_bf_last_re;
         data_im_o <= data_bf_last_im;
         stage0_ctr <= stage0_ctr + 1'b1;

         if (sync_o == 1'b1) begin
            data_ctr_bit_nrml <= data_ctr_bit_nrml + 1'b1;
         end else begin
            data_ctr_bit_nrml <= {N_LOG2{1'b0}};
         end

         if (stage4_ctr == N_STAGES-2 || sync_o == 1'b1) begin
            sync_o <= 1'b1;
         end else begin
            sync_o <= 1'b0;
         end
      end else begin // if (ce_i)
         stage0_ctr        <= {N_LOG2{1'b0}};
         data_ctr_bit_nrml <= {N_LOG2{1'b0}};
         sync_o            <= 1'b0;
      end // else: !if(ce_i)
   end // always @ (posedge clk_i)

endmodule // fft_r22sdf
