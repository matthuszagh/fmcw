`ifndef _FFT_V_
`define _FFT_V_

`default_nettype none
`timescale 1ns/1ps

`include "fft_bf.v"
`include "fft_wm.v"
`include "ff_sync.v"

// Radix-2^2 SDF FFT implementation.
//
// N must be a power of 4. Currently, any power of 4 <= 1024 is
// supported, but this could easily be extended to greater lengths.
//
// Ports:
// en : Input data treated as valid. valid and data_ctr_o are based on
//      when this is asserted.

// TODO last rom file doesn't appear to be needed. Verify and remove
// from generation script.

module fft #(
   parameter N             = 1024, /* FFT length */
   parameter INPUT_WIDTH   = 13,
   parameter TWIDDLE_WIDTH = 18,
   // +1 comes from complex multiply, which is really the sum of 2
   // multiplies for each complex component.
   parameter OUTPUT_WIDTH  = 24   /* $clog2(N) + INPUT_WIDTH + 1 */
) (
   input wire                           clk,
   input wire                           arst_n,
   input wire                           en,
   output reg                           valid = 1'b0,
   output wire [$clog2(N)-1:0]          data_ctr_o,
   input wire signed [INPUT_WIDTH-1:0]  data_re_i,
   input wire signed [INPUT_WIDTH-1:0]  data_im_i,
   output reg signed [OUTPUT_WIDTH-1:0] data_re_o,
   output reg signed [OUTPUT_WIDTH-1:0] data_im_o
);

   localparam N_STAGES = $clog2(N) / 2;

   wire                                 srst_n;
   ff_sync #(
      .WIDTH  (1),
      .STAGES (2)
   ) rst_sync (
      .dest_clk (clk    ),
      .d        (arst_n ),
      .q        (srst_n )
   );

   // non bit-reversed output data count
   reg [$clog2(N)-1:0]                  data_ctr_bit_nrml = {$clog2(N){1'b0}};

   // twiddle factors
   wire signed [TWIDDLE_WIDTH-1:0]      w_s0_re;
   ram #(
      .INITFILE ("s0_re.hex"   ),
      .WIDTH    (TWIDDLE_WIDTH ),
      .SIZE     (N             )
   ) rom_s0_re (
      .rdclk  (clk                   ),
      .rden   (1'b1                  ),
      .rdaddr (stage1_ctr_wm         ),
      .rddata (w_s0_re               ),
      .wrclk  (1'b0                  ),
      .wren   (1'b0                  ),
      .wraddr ({$clog2(N){1'b0}}     ),
      .wrdata ({TWIDDLE_WIDTH{1'b0}} )
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s0_im;
   ram #(
      .INITFILE ("s0_im.hex"   ),
      .WIDTH    (TWIDDLE_WIDTH ),
      .SIZE     (N             )
   ) rom_s0_im (
      .rdclk  (clk                   ),
      .rden   (1'b1                  ),
      .rdaddr (stage1_ctr_wm         ),
      .rddata (w_s0_im               ),
      .wrclk  (1'b0                  ),
      .wren   (1'b0                  ),
      .wraddr ({$clog2(N){1'b0}}     ),
      .wrdata ({TWIDDLE_WIDTH{1'b0}} )
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s1_re;
   ram #(
      .INITFILE ("s1_re.hex"   ),
      .WIDTH    (TWIDDLE_WIDTH ),
      .SIZE     (N/4           )
   ) rom_s1_re (
      .rdclk  (clk                          ),
      .rden   (1'b1                         ),
      .rdaddr (stage2_ctr_wm[$clog2(N)-3:0] ),
      .rddata (w_s1_re                      ),
      .wrclk  (1'b0                         ),
      .wren   (1'b0                         ),
      .wraddr ({$clog2(N)-2{1'b0}}          ),
      .wrdata ({TWIDDLE_WIDTH{1'b0}}        )
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s1_im;
   ram #(
      .INITFILE ("s1_im.hex"   ),
      .WIDTH    (TWIDDLE_WIDTH ),
      .SIZE     (N/4           )
   ) rom_s1_im (
      .rdclk  (clk                          ),
      .rden   (1'b1                         ),
      .rdaddr (stage2_ctr_wm[$clog2(N)-3:0] ),
      .rddata (w_s1_im                      ),
      .wrclk  (1'b0                         ),
      .wren   (1'b0                         ),
      .wraddr ({$clog2(N)-2{1'b0}}          ),
      .wrdata ({TWIDDLE_WIDTH{1'b0}}        )
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s2_re;
   ram #(
      .INITFILE ("s2_re.hex"   ),
      .WIDTH    (TWIDDLE_WIDTH ),
      .SIZE     (N/16          )
   ) rom_s2_re (
      .rdclk  (clk                          ),
      .rden   (1'b1                         ),
      .rdaddr (stage3_ctr_wm[$clog2(N)-5:0] ),
      .rddata (w_s2_re                      ),
      .wrclk  (1'b0                         ),
      .wren   (1'b0                         ),
      .wraddr ({$clog2(N)-4{1'b0}}          ),
      .wrdata ({TWIDDLE_WIDTH{1'b0}}        )
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s2_im;
   ram #(
      .INITFILE ("s2_im.hex"   ),
      .WIDTH    (TWIDDLE_WIDTH ),
      .SIZE     (N/16          )
   ) rom_s2_im (
      .rdclk  (clk                          ),
      .rden   (1'b1                         ),
      .rdaddr (stage3_ctr_wm[$clog2(N)-5:0] ),
      .rddata (w_s2_im                      ),
      .wrclk  (1'b0                         ),
      .wren   (1'b0                         ),
      .wraddr ({$clog2(N)-4{1'b0}}          ),
      .wrdata ({TWIDDLE_WIDTH{1'b0}}        )
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s3_re;
   ram #(
      .INITFILE ("s3_re.hex"   ),
      .WIDTH    (TWIDDLE_WIDTH ),
      .SIZE     (N/64          )
   ) rom_s3_re (
      .rdclk  (clk                          ),
      .rden   (1'b1                         ),
      .rdaddr (stage4_ctr_wm[$clog2(N)-7:0] ),
      .rddata (w_s3_re                      ),
      .wrclk  (1'b0                         ),
      .wren   (1'b0                         ),
      .wraddr ({$clog2(N)-6{1'b0}}          ),
      .wrdata ({TWIDDLE_WIDTH{1'b0}}        )
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s3_im;
   ram #(
      .INITFILE ("s3_im.hex"   ),
      .WIDTH    (TWIDDLE_WIDTH ),
      .SIZE     (N/64          )
   ) rom_s3_im (
      .rdclk  (clk                          ),
      .rden   (1'b1                         ),
      .rdaddr (stage4_ctr_wm[$clog2(N)-7:0] ),
      .rddata (w_s3_im                      ),
      .wrclk  (1'b0                         ),
      .wren   (1'b0                         ),
      .wraddr ({$clog2(N)-6{1'b0}}          ),
      .wrdata ({TWIDDLE_WIDTH{1'b0}}        )
   );

   // stage counters
   // provide control logic to each stage
   reg [$clog2(N)-1:0]                     stage0_ctr = {$clog2(N){1'b0}};
   wire [$clog2(N)-1:0]                    stage1_ctr_wm;
   wire [$clog2(N)-1:0]                    stage1_ctr;
   wire [$clog2(N)-1:0]                    stage2_ctr_wm;
   wire [$clog2(N)-1:0]                    stage2_ctr;
   wire [$clog2(N)-1:0]                    stage3_ctr_wm;
   wire [$clog2(N)-1:0]                    stage3_ctr;
   wire [$clog2(N)-1:0]                    stage4_ctr_wm;
   wire [$clog2(N)-1:0]                    stage4_ctr;

   // output data comes out in bit-reversed order
   genvar k;
   generate
      for (k=0; k<$clog2(N); k=k+1) begin
         assign data_ctr_o[k] = data_ctr_bit_nrml[$clog2(N)-1-k];
      end
   endgenerate

   function [OUTPUT_WIDTH-1:0] sign_extend_input(input [INPUT_WIDTH-1:0] expr);
      sign_extend_input = (expr[INPUT_WIDTH-1] == 1'b1) ? {{OUTPUT_WIDTH-INPUT_WIDTH{1'b1}}, expr}
                      : {{OUTPUT_WIDTH-INPUT_WIDTH{1'b0}}, expr};
   endfunction

   // stage 0
   wire signed [OUTPUT_WIDTH-1:0] bf0_re;
   wire signed [OUTPUT_WIDTH-1:0] bf0_im;
   wire signed [OUTPUT_WIDTH-1:0] w0_re;
   wire signed [OUTPUT_WIDTH-1:0] w0_im;
   wire                           carry_0;

   fft_bf #(
      .WIDTH (OUTPUT_WIDTH ),
      .N     (N            ),
      .STAGE (0            )
   ) stage0_bf (
      .clk       (clk                          ),
      .srst_n    (srst_n                       ),
      .carry_in  (en                           ),
      .carry_out (carry_0                      ),
      .ctr_i     (stage0_ctr                   ),
      .ctr_o     (stage1_ctr_wm                ),
      .x_re_i    (sign_extend_input(data_re_i) ),
      .x_im_i    (sign_extend_input(data_im_i) ),
      .z_re_o    (bf0_re                       ),
      .z_im_o    (bf0_im                       )
   );

   // stage 1
   wire signed [OUTPUT_WIDTH-1:0] bf1_re;
   wire signed [OUTPUT_WIDTH-1:0] bf1_im;
   wire signed [OUTPUT_WIDTH-1:0] w1_re;
   wire signed [OUTPUT_WIDTH-1:0] w1_im;
   wire                           carry_11;
   wire                           carry_12;

   fft_wm #(
      .WIDTH         (OUTPUT_WIDTH  ),
      .TWIDDLE_WIDTH (TWIDDLE_WIDTH ),
      .N             (N             )
   ) stage0_wm (
      .clk       (clk           ),
      .srst_n    (srst_n        ),
      .carry_in  (carry_0       ),
      .carry_out (carry_11      ),
      .ctr_i     (stage1_ctr_wm ),
      .ctr_o     (stage1_ctr    ),
      .x_re_i    (bf0_re        ),
      .x_im_i    (bf0_im        ),
      .w_re_i    (w_s0_re       ),
      .w_im_i    (w_s0_im       ),
      .z_re_o    (w0_re         ),
      .z_im_o    (w0_im         )
   );

   fft_bf #(
      .WIDTH (OUTPUT_WIDTH ),
      .N     (N            ),
      .STAGE (1            )
   ) stage1_bf (
      .clk       (clk           ),
      .srst_n    (srst_n        ),
      .carry_in  (carry_11      ),
      .carry_out (carry_12      ),
      .ctr_i     (stage1_ctr    ),
      .ctr_o     (stage2_ctr_wm ),
      .x_re_i    (w0_re         ),
      .x_im_i    (w0_im         ),
      .z_re_o    (bf1_re        ),
      .z_im_o    (bf1_im        )
   );

   // stage 2
   wire signed [OUTPUT_WIDTH-1:0] bf2_re;
   wire signed [OUTPUT_WIDTH-1:0] bf2_im;
   wire signed [OUTPUT_WIDTH-1:0] w2_re;
   wire signed [OUTPUT_WIDTH-1:0] w2_im;
   wire                           carry_21;
   wire                           carry_22;

   fft_wm #(
      .WIDTH         (OUTPUT_WIDTH  ),
      .TWIDDLE_WIDTH (TWIDDLE_WIDTH ),
      .N             (N             )
   ) stage1_wm (
      .clk       (clk           ),
      .srst_n    (srst_n        ),
      .carry_in  (carry_12      ),
      .carry_out (carry_21      ),
      .ctr_i     (stage2_ctr_wm ),
      .ctr_o     (stage2_ctr    ),
      .x_re_i    (bf1_re        ),
      .x_im_i    (bf1_im        ),
      .w_re_i    (w_s1_re       ),
      .w_im_i    (w_s1_im       ),
      .z_re_o    (w1_re         ),
      .z_im_o    (w1_im         )
   );

   fft_bf #(
      .WIDTH (OUTPUT_WIDTH ),
      .N     (N            ),
      .STAGE (2            )
   ) stage2_bf (
      .clk       (clk           ),
      .srst_n    (srst_n        ),
      .carry_in  (carry_21      ),
      .carry_out (carry_22      ),
      .ctr_i     (stage2_ctr    ),
      .ctr_o     (stage3_ctr_wm ),
      .x_re_i    (w1_re         ),
      .x_im_i    (w1_im         ),
      .z_re_o    (bf2_re        ),
      .z_im_o    (bf2_im        )
   );

   // stage 3
   wire signed [OUTPUT_WIDTH-1:0] bf3_re;
   wire signed [OUTPUT_WIDTH-1:0] bf3_im;
   wire signed [OUTPUT_WIDTH-1:0] w3_re;
   wire signed [OUTPUT_WIDTH-1:0] w3_im;
   wire                           carry_31;
   wire                           carry_32;

   fft_wm #(
      .WIDTH         (OUTPUT_WIDTH  ),
      .TWIDDLE_WIDTH (TWIDDLE_WIDTH ),
      .N             (N             )
   ) stage2_wm (
      .clk       (clk           ),
      .srst_n    (srst_n        ),
      .carry_in  (carry_22      ),
      .carry_out (carry_31      ),
      .ctr_i     (stage3_ctr_wm ),
      .ctr_o     (stage3_ctr    ),
      .x_re_i    (bf2_re        ),
      .x_im_i    (bf2_im        ),
      .w_re_i    (w_s2_re       ),
      .w_im_i    (w_s2_im       ),
      .z_re_o    (w2_re         ),
      .z_im_o    (w2_im         )
   );

   fft_bf #(
      .WIDTH (OUTPUT_WIDTH ),
      .N     (N            ),
      .STAGE (3            )
   ) stage3_bf (
      .clk       (clk           ),
      .srst_n    (srst_n        ),
      .carry_in  (carry_31      ),
      .carry_out (carry_32      ),
      .ctr_i     (stage3_ctr    ),
      .ctr_o     (stage4_ctr_wm ),
      .x_re_i    (w2_re         ),
      .x_im_i    (w2_im         ),
      .z_re_o    (bf3_re        ),
      .z_im_o    (bf3_im        )
   );

   // stage 4
   wire signed [OUTPUT_WIDTH-1:0] bf4_re;
   wire signed [OUTPUT_WIDTH-1:0] bf4_im;
   wire                           carry_41;
   wire                           carry_42;

   fft_wm #(
      .WIDTH         (OUTPUT_WIDTH  ),
      .TWIDDLE_WIDTH (TWIDDLE_WIDTH ),
      .N             (N             )
   ) stage3_wm (
      .clk       (clk           ),
      .srst_n    (srst_n        ),
      .carry_in  (carry_32      ),
      .carry_out (carry_41      ),
      .ctr_i     (stage4_ctr_wm ),
      .ctr_o     (stage4_ctr    ),
      .x_re_i    (bf3_re        ),
      .x_im_i    (bf3_im        ),
      .w_re_i    (w_s3_re       ),
      .w_im_i    (w_s3_im       ),
      .z_re_o    (w3_re         ),
      .z_im_o    (w3_im         )
   );

   /* verilator lint_off PINMISSING */
   fft_bf #(
      .WIDTH (OUTPUT_WIDTH ),
      .N     (N            ),
      .STAGE (4            )
   ) stage4_bf (
      .clk       (clk        ),
      .srst_n    (srst_n     ),
      .carry_in  (carry_41   ),
      .carry_out (carry_42   ),
      .ctr_i     (stage4_ctr ),
      .x_re_i    (w3_re      ),
      .x_im_i    (w3_im      ),
      .z_re_o    (bf4_re     ),
      .z_im_o    (bf4_im     )
   );
   /* verilator lint_on PINMISSING */

   wire signed [OUTPUT_WIDTH-1:0] data_bf_last_re;
   wire signed [OUTPUT_WIDTH-1:0] data_bf_last_im;
   wire                           valid_next;

   assign data_bf_last_re = bf4_re;
   assign data_bf_last_im = bf4_im;
   assign valid_next      = carry_42;

   /* verilator lint_off WIDTH */
   localparam [$clog2(N)-1:0] SYNC_STAGE = N_STAGES-2;
   /* verilator lint_on WIDTH */

   always @(posedge clk) begin
      data_re_o <= data_bf_last_re;
      data_im_o <= data_bf_last_im;
      valid     <= valid_next;

      if (en) stage0_ctr <= stage0_ctr + 1'b1;
      else    stage0_ctr <= {$clog2(N){1'b0}};

      if (valid) data_ctr_bit_nrml <= data_ctr_bit_nrml + 1'b1;
      else       data_ctr_bit_nrml <= {$clog2(N){1'b0}};
   end

`ifdef COCOTB_SIM
   `ifdef FFT
      // integer i;
      initial begin
         $dumpfile ("build/fft_tb.vcd");
         $dumpvars (0, fft);
         // for (i=0; i<100; i=i+1)
         //   $dumpvars (0, ram.mem[i]);
         #1;
      end
   `endif
`endif

endmodule
`endif
