`ifndef _FIR_POLY_V_
`define _FIR_POLY_V_
`default_nettype none

`include "fir_bank.v"

`timescale 1ns/1ps
module fir #(
   parameter N_TAPS         = 120, /* total number of taps */
   parameter M              = 20,  /* decimation factor */
   parameter BANK_LEN       = 6,   /* N_TAPS/M */
   parameter INPUT_WIDTH    = 12,
   parameter TAP_WIDTH      = 16,
   // should be set equal to the
   // INPUT_WIDTH + TAP_WIDTH + ceil(log2(N_TAPS))
   parameter INTERNAL_WIDTH = 35,
   // these values should be set according to the output of
   // gen_taps.py
   parameter NORM_SHIFT     = 3,
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
   reg signed [TAP_WIDTH-1:0] taps2 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps3 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps4 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps5 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps6 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps7 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps8 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps9 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps10 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps11 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps12 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps13 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps14 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps15 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps16 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps17 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps18 [0:BANK_LEN-1];
   reg signed [TAP_WIDTH-1:0] taps19 [0:BANK_LEN-1];

   initial begin
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps0.hex", taps0);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps1.hex", taps1);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps2.hex", taps2);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps3.hex", taps3);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps4.hex", taps4);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps5.hex", taps5);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps6.hex", taps6);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps7.hex", taps7);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps8.hex", taps8);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps9.hex", taps9);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps10.hex", taps10);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps11.hex", taps11);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps12.hex", taps12);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps13.hex", taps13);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps14.hex", taps14);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps15.hex", taps15);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps16.hex", taps16);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps17.hex", taps17);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps18.hex", taps18);
      $readmemh("/home/matt/src/fmcw-radar/gateware/roms/fir/taps19.hex", taps19);
   end

   wire signed [TAP_WIDTH-1:0] tap0 = taps0[tap_addr_pipe[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap1 = taps1[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap2 = taps2[tap_addr_pipe[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap3 = taps3[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap4 = taps4[tap_addr_pipe[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap5 = taps5[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap6 = taps6[tap_addr_pipe[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap7 = taps7[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap8 = taps8[tap_addr_pipe[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap9 = taps9[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap10 = taps10[tap_addr_pipe[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap11 = taps11[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap12 = taps12[tap_addr_pipe[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap13 = taps13[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap14 = taps14[tap_addr_pipe[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap15 = taps15[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap16 = taps16[tap_addr_pipe[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap17 = taps17[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap18 = taps18[tap_addr_pipe[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap19 = taps19[tap_addr2[BANK_LEN_LOG2-1:0]];

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

   wire signed [TAP_WIDTH-1:0]         bank0_1_dsp_a = tap_addr_pipe < 5'd8 ? bank0_dsp_a : bank1_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank0_1_dsp_b = tap_addr_pipe < 5'd8 ? bank0_dsp_b : bank1_dsp_b;
   reg signed [INTERNAL_WIDTH-1:0]     bank0_1_dsp_p;
   assign bank0_dsp_p = bank0_1_dsp_p;
   assign bank1_dsp_p = bank0_1_dsp_p;

   always @(posedge clk) begin
      if (dsp_acc)
        bank0_1_dsp_p <= (bank0_1_dsp_a * bank0_1_dsp_b) + bank0_1_dsp_p;
      else
        bank0_1_dsp_p <= bank0_1_dsp_a * bank0_1_dsp_b;
   end

   wire signed [TAP_WIDTH-1:0]    bank2_dsp_a;
   wire signed [INPUT_WIDTH-1:0]  bank2_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0] bank2_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank2 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[2]),
      .dout            (bank_dout[2]),
      .tap_addr        (tap_addr_pipe),
      .tap             (tap2),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank2_dsp_a),
      .dsp_b           (bank2_dsp_b),
      .dsp_p           (bank2_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank3_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank3_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0]    bank3_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank3 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[3]),
      .dout            (bank_dout[3]),
      .tap_addr        (tap_addr2),
      .tap             (tap3),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank3_dsp_a),
      .dsp_b           (bank3_dsp_b),
      .dsp_p           (bank3_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank2_3_dsp_a = tap_addr_pipe < 5'd8 ? bank2_dsp_a : bank3_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank2_3_dsp_b = tap_addr_pipe < 5'd8 ? bank2_dsp_b : bank3_dsp_b;
   reg signed [INTERNAL_WIDTH-1:0]     bank2_3_dsp_p;
   assign bank2_dsp_p = bank2_3_dsp_p;
   assign bank3_dsp_p = bank2_3_dsp_p;

   always @(posedge clk) begin
      if (dsp_acc)
        bank2_3_dsp_p <= (bank2_3_dsp_a * bank2_3_dsp_b) + bank2_3_dsp_p;
      else
        bank2_3_dsp_p <= bank2_3_dsp_a * bank2_3_dsp_b;
   end

   wire signed [TAP_WIDTH-1:0]    bank4_dsp_a;
   wire signed [INPUT_WIDTH-1:0]  bank4_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0] bank4_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank4 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[4]),
      .dout            (bank_dout[4]),
      .tap_addr        (tap_addr_pipe),
      .tap             (tap4),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank4_dsp_a),
      .dsp_b           (bank4_dsp_b),
      .dsp_p           (bank4_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank5_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank5_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0]    bank5_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank5 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[5]),
      .dout            (bank_dout[5]),
      .tap_addr        (tap_addr2),
      .tap             (tap5),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank5_dsp_a),
      .dsp_b           (bank5_dsp_b),
      .dsp_p           (bank5_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank4_5_dsp_a = tap_addr_pipe < 5'd8 ? bank4_dsp_a : bank5_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank4_5_dsp_b = tap_addr_pipe < 5'd8 ? bank4_dsp_b : bank5_dsp_b;
   reg signed [INTERNAL_WIDTH-1:0]     bank4_5_dsp_p;
   assign bank4_dsp_p = bank4_5_dsp_p;
   assign bank5_dsp_p = bank4_5_dsp_p;

   always @(posedge clk) begin
      if (dsp_acc)
        bank4_5_dsp_p <= (bank4_5_dsp_a * bank4_5_dsp_b) + bank4_5_dsp_p;
      else
        bank4_5_dsp_p <= bank4_5_dsp_a * bank4_5_dsp_b;
   end

   wire signed [TAP_WIDTH-1:0]    bank6_dsp_a;
   wire signed [INPUT_WIDTH-1:0]  bank6_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0] bank6_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank6 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[6]),
      .dout            (bank_dout[6]),
      .tap_addr        (tap_addr_pipe),
      .tap             (tap6),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank6_dsp_a),
      .dsp_b           (bank6_dsp_b),
      .dsp_p           (bank6_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank7_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank7_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0]    bank7_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank7 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[7]),
      .dout            (bank_dout[7]),
      .tap_addr        (tap_addr2),
      .tap             (tap7),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank7_dsp_a),
      .dsp_b           (bank7_dsp_b),
      .dsp_p           (bank7_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank6_7_dsp_a = tap_addr_pipe < 5'd8 ? bank6_dsp_a : bank7_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank6_7_dsp_b = tap_addr_pipe < 5'd8 ? bank6_dsp_b : bank7_dsp_b;
   reg signed [INTERNAL_WIDTH-1:0]     bank6_7_dsp_p;
   assign bank6_dsp_p = bank6_7_dsp_p;
   assign bank7_dsp_p = bank6_7_dsp_p;

   always @(posedge clk) begin
      if (dsp_acc)
        bank6_7_dsp_p <= (bank6_7_dsp_a * bank6_7_dsp_b) + bank6_7_dsp_p;
      else
        bank6_7_dsp_p <= bank6_7_dsp_a * bank6_7_dsp_b;
   end

   wire signed [TAP_WIDTH-1:0]    bank8_dsp_a;
   wire signed [INPUT_WIDTH-1:0]  bank8_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0] bank8_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank8 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[8]),
      .dout            (bank_dout[8]),
      .tap_addr        (tap_addr_pipe),
      .tap             (tap8),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank8_dsp_a),
      .dsp_b           (bank8_dsp_b),
      .dsp_p           (bank8_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank9_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank9_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0]    bank9_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank9 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[9]),
      .dout            (bank_dout[9]),
      .tap_addr        (tap_addr2),
      .tap             (tap9),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank9_dsp_a),
      .dsp_b           (bank9_dsp_b),
      .dsp_p           (bank9_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank8_9_dsp_a = tap_addr_pipe < 5'd8 ? bank8_dsp_a : bank9_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank8_9_dsp_b = tap_addr_pipe < 5'd8 ? bank8_dsp_b : bank9_dsp_b;
   reg signed [INTERNAL_WIDTH-1:0]     bank8_9_dsp_p;
   assign bank8_dsp_p = bank8_9_dsp_p;
   assign bank9_dsp_p = bank8_9_dsp_p;

   always @(posedge clk) begin
      if (dsp_acc)
        bank8_9_dsp_p <= (bank8_9_dsp_a * bank8_9_dsp_b) + bank8_9_dsp_p;
      else
        bank8_9_dsp_p <= bank8_9_dsp_a * bank8_9_dsp_b;
   end

   wire signed [TAP_WIDTH-1:0]    bank10_dsp_a;
   wire signed [INPUT_WIDTH-1:0]  bank10_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0] bank10_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank10 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[10]),
      .dout            (bank_dout[10]),
      .tap_addr        (tap_addr_pipe),
      .tap             (tap10),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank10_dsp_a),
      .dsp_b           (bank10_dsp_b),
      .dsp_p           (bank10_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank11_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank11_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0]    bank11_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank11 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[11]),
      .dout            (bank_dout[11]),
      .tap_addr        (tap_addr2),
      .tap             (tap11),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank11_dsp_a),
      .dsp_b           (bank11_dsp_b),
      .dsp_p           (bank11_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank10_11_dsp_a = tap_addr_pipe < 5'd8 ? bank10_dsp_a : bank11_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank10_11_dsp_b = tap_addr_pipe < 5'd8 ? bank10_dsp_b : bank11_dsp_b;
   reg signed [INTERNAL_WIDTH-1:0]     bank10_11_dsp_p;
   assign bank10_dsp_p = bank10_11_dsp_p;
   assign bank11_dsp_p = bank10_11_dsp_p;

   always @(posedge clk) begin
      if (dsp_acc)
        bank10_11_dsp_p <= (bank10_11_dsp_a * bank10_11_dsp_b) + bank10_11_dsp_p;
      else
        bank10_11_dsp_p <= bank10_11_dsp_a * bank10_11_dsp_b;
   end

   wire signed [TAP_WIDTH-1:0]    bank12_dsp_a;
   wire signed [INPUT_WIDTH-1:0]  bank12_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0] bank12_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank12 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[12]),
      .dout            (bank_dout[12]),
      .tap_addr        (tap_addr_pipe),
      .tap             (tap12),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank12_dsp_a),
      .dsp_b           (bank12_dsp_b),
      .dsp_p           (bank12_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank13_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank13_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0]    bank13_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank13 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[13]),
      .dout            (bank_dout[13]),
      .tap_addr        (tap_addr2),
      .tap             (tap13),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank13_dsp_a),
      .dsp_b           (bank13_dsp_b),
      .dsp_p           (bank13_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank12_13_dsp_a = tap_addr_pipe < 5'd8 ? bank12_dsp_a : bank13_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank12_13_dsp_b = tap_addr_pipe < 5'd8 ? bank12_dsp_b : bank13_dsp_b;
   reg signed [INTERNAL_WIDTH-1:0]     bank12_13_dsp_p;
   assign bank12_dsp_p = bank12_13_dsp_p;
   assign bank13_dsp_p = bank12_13_dsp_p;

   always @(posedge clk) begin
      if (dsp_acc)
        bank12_13_dsp_p <= (bank12_13_dsp_a * bank12_13_dsp_b) + bank12_13_dsp_p;
      else
        bank12_13_dsp_p <= bank12_13_dsp_a * bank12_13_dsp_b;
   end

   wire signed [TAP_WIDTH-1:0]    bank14_dsp_a;
   wire signed [INPUT_WIDTH-1:0]  bank14_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0] bank14_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank14 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[14]),
      .dout            (bank_dout[14]),
      .tap_addr        (tap_addr_pipe),
      .tap             (tap14),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank14_dsp_a),
      .dsp_b           (bank14_dsp_b),
      .dsp_p           (bank14_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank15_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank15_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0]    bank15_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank15 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[15]),
      .dout            (bank_dout[15]),
      .tap_addr        (tap_addr2),
      .tap             (tap15),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank15_dsp_a),
      .dsp_b           (bank15_dsp_b),
      .dsp_p           (bank15_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank14_15_dsp_a = tap_addr_pipe < 5'd8 ? bank14_dsp_a : bank15_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank14_15_dsp_b = tap_addr_pipe < 5'd8 ? bank14_dsp_b : bank15_dsp_b;
   reg signed [INTERNAL_WIDTH-1:0]     bank14_15_dsp_p;
   assign bank14_dsp_p = bank14_15_dsp_p;
   assign bank15_dsp_p = bank14_15_dsp_p;

   always @(posedge clk) begin
      if (dsp_acc)
        bank14_15_dsp_p <= (bank14_15_dsp_a * bank14_15_dsp_b) + bank14_15_dsp_p;
      else
        bank14_15_dsp_p <= bank14_15_dsp_a * bank14_15_dsp_b;
   end

   wire signed [TAP_WIDTH-1:0]    bank16_dsp_a;
   wire signed [INPUT_WIDTH-1:0]  bank16_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0] bank16_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank16 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[16]),
      .dout            (bank_dout[16]),
      .tap_addr        (tap_addr_pipe),
      .tap             (tap16),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank16_dsp_a),
      .dsp_b           (bank16_dsp_b),
      .dsp_p           (bank16_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank17_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank17_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0]    bank17_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank17 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[17]),
      .dout            (bank_dout[17]),
      .tap_addr        (tap_addr2),
      .tap             (tap17),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank17_dsp_a),
      .dsp_b           (bank17_dsp_b),
      .dsp_p           (bank17_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank16_17_dsp_a = tap_addr_pipe < 5'd8 ? bank16_dsp_a : bank17_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank16_17_dsp_b = tap_addr_pipe < 5'd8 ? bank16_dsp_b : bank17_dsp_b;
   reg signed [INTERNAL_WIDTH-1:0]     bank16_17_dsp_p;
   assign bank16_dsp_p = bank16_17_dsp_p;
   assign bank17_dsp_p = bank16_17_dsp_p;

   always @(posedge clk) begin
      if (dsp_acc)
        bank16_17_dsp_p <= (bank16_17_dsp_a * bank16_17_dsp_b) + bank16_17_dsp_p;
      else
        bank16_17_dsp_p <= bank16_17_dsp_a * bank16_17_dsp_b;
   end

   wire signed [TAP_WIDTH-1:0]    bank18_dsp_a;
   wire signed [INPUT_WIDTH-1:0]    bank18_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0]    bank18_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank18 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[18]),
      .dout            (bank_dout[18]),
      .tap_addr        (tap_addr_pipe),
      .tap             (tap18),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank18_dsp_a),
      .dsp_b           (bank18_dsp_b),
      .dsp_p           (bank18_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank19_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank19_dsp_b;
   wire signed [INTERNAL_WIDTH-1:0]    bank19_dsp_p;

   fir_bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank19 (
      .clk             (clk),
      .rst_n           (rst_n),
      .din             (bank_decimated_in[19]),
      .dout            (bank_dout[19]),
      .tap_addr        (tap_addr2),
      .tap             (tap19),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank19_dsp_a),
      .dsp_b           (bank19_dsp_b),
      .dsp_p           (bank19_dsp_p)
   );

   wire signed [TAP_WIDTH-1:0]         bank18_19_dsp_a = tap_addr_pipe < 5'd8 ? bank18_dsp_a : bank19_dsp_a;
   wire signed [INPUT_WIDTH-1:0]       bank18_19_dsp_b = tap_addr_pipe < 5'd8 ? bank18_dsp_b : bank19_dsp_b;
   reg signed [INTERNAL_WIDTH-1:0]     bank18_19_dsp_p;
   assign bank18_dsp_p = bank18_19_dsp_p;
   assign bank19_dsp_p = bank18_19_dsp_p;

   always @(posedge clk) begin
      if (dsp_acc)
        bank18_19_dsp_p <= (bank18_19_dsp_a * bank18_19_dsp_b) + bank18_19_dsp_p;
      else
        bank18_19_dsp_p <= bank18_19_dsp_a * bank18_19_dsp_b;
   end

   // TODO pipeline if this is too slow.
   wire signed [INTERNAL_WIDTH-1:0] out_tmp = bank_dout[0]
        + bank_dout[1]
        + bank_dout[2]
        + bank_dout[3]
        + bank_dout[4]
        + bank_dout[5]
        + bank_dout[6]
        + bank_dout[7]
        + bank_dout[8]
        + bank_dout[9]
        + bank_dout[10]
        + bank_dout[11]
        + bank_dout[12]
        + bank_dout[13]
        + bank_dout[14]
        + bank_dout[15]
        + bank_dout[16]
        + bank_dout[17]
        + bank_dout[18]
        + bank_dout[19];

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
   // integer i;
   initial begin
      $dumpfile ("cocotb/build/fir_poly.vcd");
      $dumpvars (0, fir_poly);
      // for (i=0; i<100; i=i+1)
      //   $dumpvars (0, ram.mem[i]);
      #1;
   end
`endif

endmodule

// TODO remove
`ifdef ICARUS
`timescale 1ns/1ps
module fir_poly_tb;

   localparam M              = 20; /* downsampling factor */
   localparam M_LOG2         = 5;
   localparam INPUT_WIDTH    = 12;
   localparam INTERNAL_WIDTH = 35;
   localparam NORM_SHIFT     = 4;
   localparam OUTPUT_WIDTH   = 14;
   localparam TAP_WIDTH      = 16;
   localparam BANK_LEN       = 6; /* number of taps in each polyphase decomposition filter bank */
   localparam BANK_LEN_LOG2  = 3;
   localparam ADC_DATA_WIDTH = 12;
   localparam SAMPLE_LEN     = 10000;

   reg  clk = 0;
   reg  rst_n = 0;

   always #12.5 clk = !clk;

   initial begin
      #50 rst_n = 1;
   end

   // base clock 2mhz clock enable
   reg                  clk_2mhz_pos_en = 1'b1;
   reg [4:0]            clk_2mhz_ctr    = 5'd0;

   always @(posedge clk) begin
      if (!rst_n) begin
         clk_2mhz_pos_en <= 1'b0;
         clk_2mhz_ctr    <= 5'd0;
      end else begin
         if (clk_2mhz_ctr == 5'd19) begin
            clk_2mhz_pos_en <= 1'b1;
            clk_2mhz_ctr    <= 5'd0;
         end else begin
            clk_2mhz_pos_en <= 1'b0;
            clk_2mhz_ctr    <= clk_2mhz_ctr + 1'b1;
         end
      end
   end

   reg signed [INPUT_WIDTH-1:0] samples [0:SAMPLE_LEN-1];
   wire signed [INPUT_WIDTH-1:0] sample_in = samples[ctr];
   wire signed [OUTPUT_WIDTH-1:0] dout;
   wire                           dvalid;

   integer                      ctr = 0;
   reg                          ctr_delay = 1'b0;
   always @(posedge clk) begin
      if (!rst_n) begin
         ctr <= 0;
      end else begin
         if (ctr == 0) begin
            if (ctr_delay)
              ctr <= 1;
            if (clk_2mhz_pos_en)
              ctr_delay <= 1;
         end else begin
            if (ctr == SAMPLE_LEN-1)
              ctr <= 0;
            else
              ctr <= ctr + 1;
         end
      end
   end

   integer i, f;
   initial begin
      $dumpfile("icarus/build/fir_poly_tb.vcd");
      $dumpvars(0, fir_poly_tb);
      $dumpvars(0, dut.bank0.shift_reg[0]);

      f = $fopen("../old/tb/sample_out_real_verilog.txt", "w");

      $readmemh("../old/tb/sample_in_real.hex", samples);

      #10000000 $finish;
   end

   always @(posedge clk) begin
      if (dvalid && clk_2mhz_pos_en) begin
         $fwrite(f, "%d\n", $signed(dout));
      end
   end

   fir_poly #(
      .M              (M),
      .INPUT_WIDTH    (ADC_DATA_WIDTH),
      .INTERNAL_WIDTH (INTERNAL_WIDTH),
      .NORM_SHIFT     (NORM_SHIFT),
      .OUTPUT_WIDTH   (OUTPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .BANK_LEN       (BANK_LEN)
   ) dut (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (sample_in),
      .dout            (dout),
      .dvalid          (dvalid)
   );

endmodule

`endif
`endif
