`default_nettype none

// TODO consider using a bandpass filter instead of lowpass filter for
// the FPGA.

`include "bank.v"

module fir_poly #(
   parameter N_TAPS         = 120, /* total number of taps */
   parameter M              = 20,  /* decimation factor */
   parameter BANK_LEN       = 6,   /* N_TAPS/M */
   parameter INPUT_WIDTH    = 12,
   parameter TAP_WIDTH      = 16,
   parameter INTERNAL_WIDTH = 35,
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

   localparam DSP_A_WIDTH = 25;
   localparam DSP_B_WIDTH = 18;
   localparam DSP_P_WIDTH = 48;

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

   reg signed [INPUT_WIDTH-1:0]     bank_din [0:M/2-1];
   always @(posedge clk) begin
      if (!rst_n) begin
         for (i=0; i<M; i=i+2)
           bank_din[i/2] <= {INPUT_WIDTH{1'b0}};
      end else if (tap_addr == 5'd19) begin
         bank_din[0] <= din;
         for (i=2; i<M; i=i+2)
           bank_din[i/2] <= shift_reg[i-1];
      end
   end

   wire dsp_acc = ((tap_addr != {M_LOG2{1'b0}}) && (tap_addr2 != {M_LOG2{1'b0}}));

   reg [M_LOG2:0]     tap_addr;

   always @(posedge clk) begin
      if (!rst_n) begin
         tap_addr <= {M_LOG2+1{1'b0}};
      end else begin
         tap_addr <= tap_addr + 1'b1;
         if (clk_2mhz_pos_en) begin
            tap_addr <= {M_LOG2+1{1'b0}};
         end
      end
   end

   wire [M_LOG2-1:0] tap_addr2 = tap_addr - 5'd9;

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
      $readmemh("fir/taps/taps0.hex", taps0);
      $readmemh("fir/taps/taps1.hex", taps1);
      $readmemh("fir/taps/taps2.hex", taps2);
      $readmemh("fir/taps/taps3.hex", taps3);
      $readmemh("fir/taps/taps4.hex", taps4);
      $readmemh("fir/taps/taps5.hex", taps5);
      $readmemh("fir/taps/taps6.hex", taps6);
      $readmemh("fir/taps/taps7.hex", taps7);
      $readmemh("fir/taps/taps8.hex", taps8);
      $readmemh("fir/taps/taps9.hex", taps9);
      $readmemh("fir/taps/taps10.hex", taps10);
      $readmemh("fir/taps/taps11.hex", taps11);
      $readmemh("fir/taps/taps12.hex", taps12);
      $readmemh("fir/taps/taps13.hex", taps13);
      $readmemh("fir/taps/taps14.hex", taps14);
      $readmemh("fir/taps/taps15.hex", taps15);
      $readmemh("fir/taps/taps16.hex", taps16);
      $readmemh("fir/taps/taps17.hex", taps17);
      $readmemh("fir/taps/taps18.hex", taps18);
      $readmemh("fir/taps/taps19.hex", taps19);
   end

   wire signed [TAP_WIDTH-1:0] tap0 = taps0[tap_addr[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap1 = taps1[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap2 = taps2[tap_addr[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap3 = taps3[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap4 = taps4[tap_addr[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap5 = taps5[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap6 = taps6[tap_addr[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap7 = taps7[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap8 = taps8[tap_addr[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap9 = taps9[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap10 = taps10[tap_addr[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap11 = taps11[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap12 = taps12[tap_addr[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap13 = taps13[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap14 = taps14[tap_addr[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap15 = taps15[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap16 = taps16[tap_addr[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap17 = taps17[tap_addr2[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap18 = taps18[tap_addr[BANK_LEN_LOG2-1:0]];
   wire signed [TAP_WIDTH-1:0] tap19 = taps19[tap_addr2[BANK_LEN_LOG2-1:0]];

   wire signed [INTERNAL_WIDTH-1:0] bank_dout [0:M-1];

   wire signed [DSP_A_WIDTH-1:0]    bank0_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank0_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank0_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank0 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (din),
      .dout            (bank_dout[0]),
      .tap_addr        (tap_addr),
      .tap             (tap0),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank0_dsp_a),
      .dsp_b           (bank0_dsp_b),
      .dsp_p           (bank0_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank1_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank1_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank1_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank1 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (bank_din[0]),
      .dout            (bank_dout[1]),
      .tap_addr        (tap_addr2),
      .tap             (tap1),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank1_dsp_a),
      .dsp_b           (bank1_dsp_b),
      .dsp_p           (bank1_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank0_1_dsp_a = tap_addr < 5'd8 ? bank0_dsp_a : bank1_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank0_1_dsp_b = tap_addr < 5'd8 ? bank0_dsp_b : bank1_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank0_1_dsp_p;
   assign bank0_dsp_p = bank0_1_dsp_p;
   assign bank1_dsp_p = bank0_1_dsp_p;

   dsp bank0_1_dsp (
      .clk (clk),
      .acc (dsp_acc),
      .a   (bank0_1_dsp_a),
      .b   (bank0_1_dsp_b),
      .p   (bank0_1_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank2_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank2_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank2_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank2 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (shift_reg[1]),
      .dout            (bank_dout[2]),
      .tap_addr        (tap_addr),
      .tap             (tap2),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank2_dsp_a),
      .dsp_b           (bank2_dsp_b),
      .dsp_p           (bank2_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank3_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank3_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank3_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank3 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (bank_din[1]),
      .dout            (bank_dout[3]),
      .tap_addr        (tap_addr2),
      .tap             (tap3),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank3_dsp_a),
      .dsp_b           (bank3_dsp_b),
      .dsp_p           (bank3_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank2_3_dsp_a = tap_addr < 5'd8 ? bank2_dsp_a : bank3_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank2_3_dsp_b = tap_addr < 5'd8 ? bank2_dsp_b : bank3_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank2_3_dsp_p;
   assign bank2_dsp_p = bank2_3_dsp_p;
   assign bank3_dsp_p = bank2_3_dsp_p;

   dsp bank2_3_dsp (
      .clk (clk),
      .acc (dsp_acc),
      .a   (bank2_3_dsp_a),
      .b   (bank2_3_dsp_b),
      .p   (bank2_3_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank4_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank4_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank4_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank4 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (shift_reg[3]),
      .dout            (bank_dout[4]),
      .tap_addr        (tap_addr),
      .tap             (tap4),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank4_dsp_a),
      .dsp_b           (bank4_dsp_b),
      .dsp_p           (bank4_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank5_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank5_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank5_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank5 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (bank_din[2]),
      .dout            (bank_dout[5]),
      .tap_addr        (tap_addr2),
      .tap             (tap5),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank5_dsp_a),
      .dsp_b           (bank5_dsp_b),
      .dsp_p           (bank5_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank4_5_dsp_a = tap_addr < 5'd8 ? bank4_dsp_a : bank5_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank4_5_dsp_b = tap_addr < 5'd8 ? bank4_dsp_b : bank5_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank4_5_dsp_p;
   assign bank4_dsp_p = bank4_5_dsp_p;
   assign bank5_dsp_p = bank4_5_dsp_p;

   dsp bank4_5_dsp (
      .clk (clk),
      .acc (dsp_acc),
      .a   (bank4_5_dsp_a),
      .b   (bank4_5_dsp_b),
      .p   (bank4_5_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank6_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank6_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank6_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank6 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (shift_reg[5]),
      .dout            (bank_dout[6]),
      .tap_addr        (tap_addr),
      .tap             (tap6),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank6_dsp_a),
      .dsp_b           (bank6_dsp_b),
      .dsp_p           (bank6_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank7_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank7_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank7_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank7 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (bank_din[3]),
      .dout            (bank_dout[7]),
      .tap_addr        (tap_addr2),
      .tap             (tap7),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank7_dsp_a),
      .dsp_b           (bank7_dsp_b),
      .dsp_p           (bank7_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank6_7_dsp_a = tap_addr < 5'd8 ? bank6_dsp_a : bank7_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank6_7_dsp_b = tap_addr < 5'd8 ? bank6_dsp_b : bank7_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank6_7_dsp_p;
   assign bank6_dsp_p = bank6_7_dsp_p;
   assign bank7_dsp_p = bank6_7_dsp_p;

   dsp bank6_7_dsp (
      .clk (clk),
      .acc (dsp_acc),
      .a   (bank6_7_dsp_a),
      .b   (bank6_7_dsp_b),
      .p   (bank6_7_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank8_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank8_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank8_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank8 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (shift_reg[7]),
      .dout            (bank_dout[8]),
      .tap_addr        (tap_addr),
      .tap             (tap8),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank8_dsp_a),
      .dsp_b           (bank8_dsp_b),
      .dsp_p           (bank8_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank9_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank9_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank9_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank9 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (bank_din[4]),
      .dout            (bank_dout[9]),
      .tap_addr        (tap_addr2),
      .tap             (tap9),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank9_dsp_a),
      .dsp_b           (bank9_dsp_b),
      .dsp_p           (bank9_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank8_9_dsp_a = tap_addr < 5'd8 ? bank8_dsp_a : bank9_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank8_9_dsp_b = tap_addr < 5'd8 ? bank8_dsp_b : bank9_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank8_9_dsp_p;
   assign bank8_dsp_p = bank8_9_dsp_p;
   assign bank9_dsp_p = bank8_9_dsp_p;

   dsp bank8_9_dsp (
      .clk (clk),
      .acc (dsp_acc),
      .a   (bank8_9_dsp_a),
      .b   (bank8_9_dsp_b),
      .p   (bank8_9_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank10_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank10_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank10_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank10 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (shift_reg[9]),
      .dout            (bank_dout[10]),
      .tap_addr        (tap_addr),
      .tap             (tap10),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank10_dsp_a),
      .dsp_b           (bank10_dsp_b),
      .dsp_p           (bank10_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank11_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank11_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank11_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank11 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (bank_din[5]),
      .dout            (bank_dout[11]),
      .tap_addr        (tap_addr2),
      .tap             (tap11),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank11_dsp_a),
      .dsp_b           (bank11_dsp_b),
      .dsp_p           (bank11_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank10_11_dsp_a = tap_addr < 5'd8 ? bank10_dsp_a : bank11_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank10_11_dsp_b = tap_addr < 5'd8 ? bank10_dsp_b : bank11_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank10_11_dsp_p;
   assign bank10_dsp_p = bank10_11_dsp_p;
   assign bank11_dsp_p = bank10_11_dsp_p;

   dsp bank10_11_dsp (
      .clk (clk),
      .acc (dsp_acc),
      .a   (bank10_11_dsp_a),
      .b   (bank10_11_dsp_b),
      .p   (bank10_11_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank12_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank12_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank12_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank12 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (shift_reg[11]),
      .dout            (bank_dout[12]),
      .tap_addr        (tap_addr),
      .tap             (tap12),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank12_dsp_a),
      .dsp_b           (bank12_dsp_b),
      .dsp_p           (bank12_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank13_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank13_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank13_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank13 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (bank_din[6]),
      .dout            (bank_dout[13]),
      .tap_addr        (tap_addr2),
      .tap             (tap13),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank13_dsp_a),
      .dsp_b           (bank13_dsp_b),
      .dsp_p           (bank13_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank12_13_dsp_a = tap_addr < 5'd8 ? bank12_dsp_a : bank13_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank12_13_dsp_b = tap_addr < 5'd8 ? bank12_dsp_b : bank13_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank12_13_dsp_p;
   assign bank12_dsp_p = bank12_13_dsp_p;
   assign bank13_dsp_p = bank12_13_dsp_p;

   dsp bank12_13_dsp (
      .clk (clk),
      .acc (dsp_acc),
      .a   (bank12_13_dsp_a),
      .b   (bank12_13_dsp_b),
      .p   (bank12_13_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank14_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank14_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank14_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank14 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (shift_reg[13]),
      .dout            (bank_dout[14]),
      .tap_addr        (tap_addr),
      .tap             (tap14),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank14_dsp_a),
      .dsp_b           (bank14_dsp_b),
      .dsp_p           (bank14_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank15_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank15_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank15_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank15 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (bank_din[7]),
      .dout            (bank_dout[15]),
      .tap_addr        (tap_addr2),
      .tap             (tap15),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank15_dsp_a),
      .dsp_b           (bank15_dsp_b),
      .dsp_p           (bank15_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank14_15_dsp_a = tap_addr < 5'd8 ? bank14_dsp_a : bank15_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank14_15_dsp_b = tap_addr < 5'd8 ? bank14_dsp_b : bank15_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank14_15_dsp_p;
   assign bank14_dsp_p = bank14_15_dsp_p;
   assign bank15_dsp_p = bank14_15_dsp_p;

   dsp bank14_15_dsp (
      .clk (clk),
      .acc (dsp_acc),
      .a   (bank14_15_dsp_a),
      .b   (bank14_15_dsp_b),
      .p   (bank14_15_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank16_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank16_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank16_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank16 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (shift_reg[15]),
      .dout            (bank_dout[16]),
      .tap_addr        (tap_addr),
      .tap             (tap16),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank16_dsp_a),
      .dsp_b           (bank16_dsp_b),
      .dsp_p           (bank16_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank17_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank17_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank17_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank17 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (bank_din[8]),
      .dout            (bank_dout[17]),
      .tap_addr        (tap_addr2),
      .tap             (tap17),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank17_dsp_a),
      .dsp_b           (bank17_dsp_b),
      .dsp_p           (bank17_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank16_17_dsp_a = tap_addr < 5'd8 ? bank16_dsp_a : bank17_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank16_17_dsp_b = tap_addr < 5'd8 ? bank16_dsp_b : bank17_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank16_17_dsp_p;
   assign bank16_dsp_p = bank16_17_dsp_p;
   assign bank17_dsp_p = bank16_17_dsp_p;

   dsp bank16_17_dsp (
      .clk (clk),
      .acc (dsp_acc),
      .a   (bank16_17_dsp_a),
      .b   (bank16_17_dsp_b),
      .p   (bank16_17_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank18_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank18_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank18_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank18 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (shift_reg[17]),
      .dout            (bank_dout[18]),
      .tap_addr        (tap_addr),
      .tap             (tap18),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank18_dsp_a),
      .dsp_b           (bank18_dsp_b),
      .dsp_p           (bank18_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank19_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank19_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank19_dsp_p;

   bank #(
      .N_TAPS         (N_TAPS),
      .M              (M),
      .BANK_LEN       (BANK_LEN),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TAP_WIDTH      (TAP_WIDTH),
      .OUTPUT_WIDTH   (INTERNAL_WIDTH)
   ) bank19 (
      .clk             (clk),
      .rst_n           (rst_n),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (bank_din[9]),
      .dout            (bank_dout[19]),
      .tap_addr        (tap_addr2),
      .tap             (tap19),
      .dsp_acc         (dsp_acc),
      .dsp_a           (bank19_dsp_a),
      .dsp_b           (bank19_dsp_b),
      .dsp_p           (bank19_dsp_p)
   );

   wire signed [DSP_A_WIDTH-1:0]    bank18_19_dsp_a = tap_addr < 5'd8 ? bank18_dsp_a : bank19_dsp_a;
   wire signed [DSP_B_WIDTH-1:0]    bank18_19_dsp_b = tap_addr < 5'd8 ? bank18_dsp_b : bank19_dsp_b;
   wire signed [DSP_P_WIDTH-1:0]    bank18_19_dsp_p;
   assign bank18_dsp_p = bank18_19_dsp_p;
   assign bank19_dsp_p = bank18_19_dsp_p;

   dsp bank18_19_dsp (
      .clk (clk),
      .acc (dsp_acc),
      .a   (bank18_19_dsp_a),
      .b   (bank18_19_dsp_b),
      .p   (bank18_19_dsp_p)
   );

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

   localparam DROP_LSB_BITS = TAP_WIDTH+NORM_SHIFT;
   localparam DROP_MSB_BITS = INTERNAL_WIDTH-DROP_LSB_BITS-OUTPUT_WIDTH;
   // convergent rounding
   wire signed [INTERNAL_WIDTH-1:0] out_rounded = out_tmp
        + {{DROP_LSB_BITS{1'b0}},
           out_tmp[INTERNAL_WIDTH-DROP_LSB_BITS],
           {INTERNAL_WIDTH-DROP_LSB_BITS-1{!out_tmp[INTERNAL_WIDTH-DROP_LSB_BITS]}}};

   wire signed [INTERNAL_WIDTH-DROP_MSB_BITS-1:0] out_drop_msb = out_rounded[INTERNAL_WIDTH-DROP_MSB_BITS-1:0];

   reg                                            dvalid_delay;

   // compute the sum of all bank outputs
   always @(posedge clk) begin
      if (!rst_n) begin
         dvalid <= 1'b0;
         dvalid_delay <= 1'b0;
      end else begin
         if (clk_2mhz_pos_en) begin
            if (dvalid_delay)
              dvalid <= 1'b1;
            else
              dvalid_delay <= 1'b1;

            // dout   <= out_drop_msb[INTERNAL_WIDTH-DROP_MSB_BITS-1:DROP_LSB_BITS];
            // TODO I'm not rounding well, which could give this a bit of a bias.
            dout     <= {out_tmp[INTERNAL_WIDTH-1], out_tmp[DROP_LSB_BITS+OUTPUT_WIDTH-3:DROP_LSB_BITS-1]};
         end
      end
   end

endmodule

`ifdef SIMULATE

`include "DSP48E1.v"
`include "glbl.v"

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
            ctr <= ctr + 1;
         end
      end
   end

   integer i, f;
   initial begin
      $dumpfile("tb/fir_poly.vcd");
      $dumpvars(0, fir_poly_tb);
      $dumpvars(0, dut.bank0.shift_reg[0]);

      f = $fopen("tb/sample_out_verilog.txt", "w");

      $readmemh("tb/sample_in.hex", samples);

      #100000 $finish;
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
// Local Variables:
// flycheck-verilator-include-path:("/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unimacro/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unisims/")
// End:
