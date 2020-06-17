`ifndef _FIR2_1_V_
`define _FIR2_1_V_
`default_nettype none

`include "fir2_1_bank.v"

`timescale 1ns/1ps
module fir2_1 #(
   parameter N_TAPS         = 120, /* total number of taps */
   parameter M              = 2,   /* decimation factor */
   parameter BANK_LEN       = 60,  /* N_TAPS/M */
   parameter INPUT_WIDTH    = 13,
   parameter TAP_WIDTH      = 16,
   // should be set equal to the
   // INPUT_WIDTH + TAP_WIDTH + ceil(log2(N_TAPS))
   parameter INTERNAL_WIDTH = 36,
   // these values should be set according to the output of
   // gen_taps.py
   parameter NORM_SHIFT     = 4,
   parameter OUTPUT_WIDTH   = 14
) (
   input wire                           clk,
   input wire                           rst_n,
   input wire                           clk_2mhz_pos_en,
   input wire signed [INPUT_WIDTH-1:0]  din,
   output reg signed [OUTPUT_WIDTH-1:0] dout,
   output reg                           dvalid
);

   localparam M_LOG2        = $clog2(M);
   localparam BANK_LEN_LOG2 = $clog2(BANK_LEN);

   // Data is first passed through a shift register at the base clock
   // rate. The first polyphase bank gets its data directly from the
   // input and therefore doesn't need a shift register.
   reg signed [INPUT_WIDTH-1:0]         shift_reg [0:M-2];

   integer                              i;
   always @(posedge clk) begin
      if (!rst_n) begin
         for (i=0; i<M-1; i=i+1)
           shift_reg[i] <= {INPUT_WIDTH{1'b0}};
      end else begin
         shift_reg[0] <= din;
         for (i=1; i<M-1; i=i+1)
           shift_reg[i] <= shift_reg[i-1];
      end
   end

   // Decimate the input signal by the downsampling factor. We can get
   // away with M/2 since half the inputs will arrive at the right
   // time (those where the accumulation starts on tap_addr == 0). The
   // other half need to be registered. This relates to the way the
   // multiply is time-multiplexed.
   reg signed [INPUT_WIDTH-1:0]     bank_decimated_in [0:M-1];
   always @(posedge clk) begin
      if (!rst_n) begin
         for (i=0; i<M; i=i+1)
           bank_decimated_in[i] <= {INPUT_WIDTH{1'b0}};
      end else if (tap_addr == 5'd0) begin
         bank_decimated_in[0] <= din;
         for (i=1; i<M; i=i+1)
           bank_decimated_in[i] <= shift_reg[i-1];
      end
   end

   reg [M_LOG2-1:0]     tap_addr;
   reg [M_LOG2-1:0]     tap_addr_pipe;

   always @(posedge clk) begin
      if (!rst_n) begin
         tap_addr <= {M_LOG2{1'b0}};
         tap_addr_pipe <= {M_LOG2{1'b0}};
      end else begin
         tap_addr_pipe <= tap_addr;
         tap_addr <= tap_addr + 1'b1;
         if (clk_2mhz_pos_en) begin
            tap_addr <= {M_LOG2{1'b0}};
         end
      end
   end

   wire [M_LOG2-1:0] tap_addr2 = tap_addr_pipe - 5'd9;
   wire dsp_acc = ((tap_addr_pipe != {M_LOG2{1'b0}}) && (tap_addr2 != {M_LOG2{1'b0}}));

   reg signed [TAP_WIDTH-1:0] taps0 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps1 [0:BANK_LEN-1];

   initial begin
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/2_1/taps0.hex", taps0);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/2_1/taps1.hex", taps1);
   end

   wire signed [TAP_WIDTH-1:0] tap0 = taps0[tap_addr_pipe[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap1 = taps1[tap_addr2[BANK_LEN_LOG2-1:0]];

   wire signed [INTERNAL_WIDTH-1:0] bank_dout [0:M-1];

   wire signed [TAP_WIDTH-1:0]      bank0_dsp_a;
   wire signed [INPUT_WIDTH-1:0]    bank0_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0] bank0_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank0 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[0]),
      .dout            (bank_dout[0]),
      .tap_addr        (tap_addr_pipe),
      .tap             (tap0),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank0_dsp_a),
      .dsp_b           (bank0_dsp_b),
      .dsp_p           (bank0_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank1_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank1_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0]    bank1_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank1 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[1]),
      .dout            (bank_dout[1]),
      .tap_addr        (tap_addr2),
      .tap             (tap1),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank1_dsp_a),
      .dsp_b           (bank1_dsp_b),
      .dsp_p           (bank1_dsp_p)
   );

   wire signed [INTERNAL_WIDTH-1:0] out_tmp = bank_dout[0] + bank_dout[1];

   // -1 comes from the fact that taps are two's complement and so
   // we're dividing by 2^(n-1)
   localparam DROP_LSB_BITS = TAP_WIDTH - 1 + NORM_SHIFT;
   // since we compute the maximum value that an output can take, we
   // can drop bits at the top.
   localparam DROP_MSB_BITS = INTERNAL_WIDTH - OUTPUT_WIDTH - DROP_LSB_BITS;
   localparam INTERNAL_MIN_MSB = INTERNAL_WIDTH-DROP_MSB_BITS;

   function [INTERNAL_MIN_MSB-1:0] drop_msb_bits(input [INTERNAL_WIDTH-1:0] expr);
      drop_msb_bits = expr[INTERNAL_MIN_MSB-1:0];
   endfunction

   function [INTERNAL_MIN_MSB-1:0] round_convergent(input [INTERNAL_MIN_MSB-1:0] expr);
      round_convergent = expr + {{OUTPUT_WIDTH{1'b0}},
                                 expr[INTERNAL_MIN_MSB-OUTPUT_WIDTH],
                                 {INTERNAL_MIN_MSB-OUTPUT_WIDTH-1{!expr[INTERNAL_MIN_MSB-OUTPUT_WIDTH]}}};
   endfunction

   function [OUTPUT_WIDTH-1:0] trunc_to_out(input [INTERNAL_MIN_MSB-1:0] expr);
      trunc_to_out = expr[INTERNAL_MIN_MSB-1:INTERNAL_MIN_MSB-OUTPUT_WIDTH];
   endfunction

   reg                              dvalid_delay;
   // compute the sum of all bank outputs
   always @(posedge clk) begin
      if (!rst_n) begin
         dvalid <= 1'b0;
         dvalid_delay <= 1'b0;
      end else begin
         if (clk_2mhz_pos_en) begin
            dvalid_delay <= 1'b1;
            if (dvalid_delay)
              dvalid <= 1'b1;

            dout <= trunc_to_out(round_convergent(drop_msb_bits(out_tmp)));
            // Simple truncation. Can be used to test effect of
            // convergent rounding.
            // dout <= out_tmp[INTERNAL_MIN_MSB-1:INTERNAL_MIN_MSB-OUTPUT_WIDTH];
         end
      end
   end

`ifdef COCOTB_SIM
   `ifdef FIR
   // integer i;
   initial begin
      $dumpfile ("cocotb/build/fir.vcd");
      $dumpvars (0, fir);
      // for (i=0; i<100; i=i+1)
      //   $dumpvars (0, ram.mem[i]);
      #1;
   end
   `endif
`endif

endmodule
`endif
