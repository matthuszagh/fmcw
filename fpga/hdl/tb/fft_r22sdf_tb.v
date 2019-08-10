`default_nettype none

`include "../fmcw_defines.vh"
`include "../fft_r22sdf.v"

module fft_r22sdf_tb #( `FMCW_DEFAULT_PARAMS );

   reg clk = 0;
   reg [OW-1:0] samples [0:FFT_N-1];
   wire [OW-1:0] data_i;
   wire          sync;
   wire [FFT_NLOG2-1:0] data_cnt;
   wire [OW-1:0] data_re_o;
   wire [OW-1:0] data_im_o;
   reg [FFT_NLOG2-1:0] cnt;

   assign data_i = samples[cnt];

   integer             idx;
   initial begin
      $dumpfile("fft_r22sdf_tb.vcd");
      $dumpvars;
      // for (idx=0; idx<FFT_N; idx=idx+1) begin
      //    $dumpvars(0, tb.w_s0_re[idx]);
      //    $dumpvars(0, tb.w_s0_im[idx]);
      // end
      $dumpvars(0, tb.stage0_bf.bfi.fsr_re[0]);
      $dumpvars(0, tb.stage0_bf.bfi.fsr_re[1]);
      $dumpvars(0, tb.stage0_bf.bfi.fsr_re[511]);
      $dumpvars(0, tb.stage0_bf.bfii.fsr_re[0]);
      $dumpvars(0, tb.stage0_bf.bfii.fsr_re[255]);
      $dumpvars(0, tb.stage1_bf.bfi.fsr_re[0]);
      $dumpvars(0, tb.stage1_bf.bfi.fsr_re[127]);
      $dumpvars(0, tb.stage1_bf.bfii.fsr_re[0]);
      $dumpvars(0, tb.stage1_bf.bfii.fsr_re[63]);
      $dumpvars(0, tb.stage2_bf.bfi.fsr_re[0]);
      $dumpvars(0, tb.stage2_bf.bfi.fsr_re[31]);
      $dumpvars(0, tb.stage2_bf.bfii.fsr_re[0]);
      $dumpvars(0, tb.stage2_bf.bfii.fsr_re[15]);
      $dumpvars(0, tb.stage3_bf.bfi.fsr_re[0]);
      $dumpvars(0, tb.stage3_bf.bfi.fsr_re[7]);
      $dumpvars(0, tb.stage3_bf.bfii.fsr_re[0]);
      $dumpvars(0, tb.stage3_bf.bfii.fsr_re[3]);
      $dumpvars(0, tb.stage4_bf.bfi.fsr_re[0]);
      $dumpvars(0, tb.stage4_bf.bfi.fsr_re[1]);
      $dumpvars(0, tb.stage4_bf.bfii.fsr_re[0]);

      $readmemh("fft_r22sdf.hex", samples);
      cnt = 0;

      #120000 $finish;
   end

   always #25 clk = !clk;

   always @(posedge clk) begin
      if (cnt == FFT_N) begin
         cnt <= cnt;
      end
      else begin
         cnt <= cnt + 1;
      end
   end

   fft_r22sdf tb (.clk_i     (clk),
                  .ce_i      (1'b1),
                  .sync_o    (sync),
                  .data_cnt  (data_cnt),
                  .data_re_i ($signed(data_i)),
                  .data_im_i (0),
                  .data_re_o (data_re_o),
                  .data_im_o (data_im_o));

endmodule // fft_r22sdf_tb

// Local Variables:
// verilog-library-directories:("." "../")
// End:
