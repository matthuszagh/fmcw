`default_nettype none

// 2-channel polyphase FIR filter.

`include "fir_poly.v"

`ifndef FILE_TAPS0_1
 `define FILE_TAPS0_1   "taps/taps0_1.hex"
`endif

`ifndef FILE_TAPS2_3
 `define FILE_TAPS2_3   "taps/taps2_3.hex"
`endif

`ifndef FILE_TAPS4_5
 `define FILE_TAPS4_5   "taps/taps4_5.hex"
`endif

`ifndef FILE_TAPS6_7
 `define FILE_TAPS6_7   "taps/taps6_7.hex"
`endif

`ifndef FILE_TAPS8_9
 `define FILE_TAPS8_9   "taps/taps8_9.hex"
`endif

`ifndef FILE_TAPS10_11
 `define FILE_TAPS10_11 "taps/taps10_11.hex"
`endif

`ifndef FILE_TAPS12_13
 `define FILE_TAPS12_13 "taps/taps12_13.hex"
`endif

`ifndef FILE_TAPS14_15
 `define FILE_TAPS14_15 "taps/taps14_15.hex"
`endif

`ifndef FILE_TAPS16_17
 `define FILE_TAPS16_17 "taps/taps16_17.hex"
`endif

`ifndef FILE_TAPS18_19
 `define FILE_TAPS18_19 "taps/taps18_19.hex"
`endif

module fir #(
   parameter M                  = 20, /* downsampling factor */
   parameter M_WIDTH            = 5,
   parameter INPUT_WIDTH        = 12,
   parameter INTERNAL_WIDTH     = 39,
   parameter NORM_SHIFT         = 4,
   parameter OUTPUT_WIDTH       = 14,
   parameter TAP_WIDTH          = 16,
   parameter POLY_BANK_LEN      = 60, /* number of taps in each polyphase decomposition filter bank */
   parameter POLY_BANK_LEN_LOG2 = 6,
   parameter ROM_SIZE           = 128
) (
   input wire                             clk_i,
   input wire                             clk_120mhz_i,
   input wire                             clk_2mhz_pos_en_i,
   input wire                             ce_i,
   input wire signed [INPUT_WIDTH-1:0]    chan_a_di_i,
   input wire signed [INPUT_WIDTH-1:0]    chan_b_di_i,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_do_o,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_do_o,

   // DSP I/O
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f0,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f1,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f2,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f3,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f4,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f5,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f6,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f7,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f8,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f9,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f10,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f11,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f12,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f13,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f14,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f15,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f16,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f17,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f18,
   input wire signed [INTERNAL_WIDTH-1:0] chan_a_f19,

   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f0,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f1,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f2,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f3,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f4,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f5,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f6,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f7,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f8,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f9,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f10,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f11,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f12,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f13,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f14,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f15,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f16,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f17,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f18,
   input wire signed [INTERNAL_WIDTH-1:0] chan_b_f19,

   output wire [POLY_BANK_LEN_LOG2-1:0]   tap_addr,

   output wire signed [TAP_WIDTH-1:0]     tap0,
   output wire signed [TAP_WIDTH-1:0]     tap1,
   output wire signed [TAP_WIDTH-1:0]     tap2,
   output wire signed [TAP_WIDTH-1:0]     tap3,
   output wire signed [TAP_WIDTH-1:0]     tap4,
   output wire signed [TAP_WIDTH-1:0]     tap5,
   output wire signed [TAP_WIDTH-1:0]     tap6,
   output wire signed [TAP_WIDTH-1:0]     tap7,
   output wire signed [TAP_WIDTH-1:0]     tap8,
   output wire signed [TAP_WIDTH-1:0]     tap9,
   output wire signed [TAP_WIDTH-1:0]     tap10,
   output wire signed [TAP_WIDTH-1:0]     tap11,
   output wire signed [TAP_WIDTH-1:0]     tap12,
   output wire signed [TAP_WIDTH-1:0]     tap13,
   output wire signed [TAP_WIDTH-1:0]     tap14,
   output wire signed [TAP_WIDTH-1:0]     tap15,
   output wire signed [TAP_WIDTH-1:0]     tap16,
   output wire signed [TAP_WIDTH-1:0]     tap17,
   output wire signed [TAP_WIDTH-1:0]     tap18,
   output wire signed [TAP_WIDTH-1:0]     tap19,

   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_0,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_1,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_2,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_3,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_4,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_5,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_6,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_7,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_8,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_9,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_10,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_11,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_12,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_13,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_14,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_15,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_16,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_17,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_18,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_a_d_2mhz_19,

   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_0,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_1,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_2,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_3,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_4,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_5,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_6,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_7,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_8,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_9,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_10,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_11,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_12,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_13,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_14,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_15,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_16,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_17,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_18,
   output wire signed [OUTPUT_WIDTH-1:0]  chan_b_d_2mhz_19
);

   assign tap_addr = addr;
   assign tap0     = h0_do;
   assign tap1     = h1_do;
   assign tap2     = h2_do;
   assign tap3     = h3_do;
   assign tap4     = h4_do;
   assign tap5     = h5_do;
   assign tap6     = h6_do;
   assign tap7     = h7_do;
   assign tap8     = h8_do;
   assign tap9     = h9_do;
   assign tap10    = h10_do;
   assign tap11    = h11_do;
   assign tap12    = h12_do;
   assign tap13    = h13_do;
   assign tap14    = h14_do;
   assign tap15    = h15_do;
   assign tap16    = h16_do;
   assign tap17    = h17_do;
   assign tap18    = h18_do;
   assign tap19    = h19_do;

   // FIR tap ROMs. Both FIR modules access the same taps at the same
   // time so the ROMs can be shared. However, this requires that the
   // ROMs are implemented at the top level and connected to the FIRs
   // with additional input/output pins.
   wire signed [TAP_WIDTH-1:0] h0_do;
   wire signed [TAP_WIDTH-1:0] h1_do;
   wire signed [TAP_WIDTH-1:0] h2_do;
   wire signed [TAP_WIDTH-1:0] h3_do;
   wire signed [TAP_WIDTH-1:0] h4_do;
   wire signed [TAP_WIDTH-1:0] h5_do;
   wire signed [TAP_WIDTH-1:0] h6_do;
   wire signed [TAP_WIDTH-1:0] h7_do;
   wire signed [TAP_WIDTH-1:0] h8_do;
   wire signed [TAP_WIDTH-1:0] h9_do;
   wire signed [TAP_WIDTH-1:0] h10_do;
   wire signed [TAP_WIDTH-1:0] h11_do;
   wire signed [TAP_WIDTH-1:0] h12_do;
   wire signed [TAP_WIDTH-1:0] h13_do;
   wire signed [TAP_WIDTH-1:0] h14_do;
   wire signed [TAP_WIDTH-1:0] h15_do;
   wire signed [TAP_WIDTH-1:0] h16_do;
   wire signed [TAP_WIDTH-1:0] h17_do;
   wire signed [TAP_WIDTH-1:0] h18_do;
   wire signed [TAP_WIDTH-1:0] h19_do;

   reg [POLY_BANK_LEN_LOG2-1:0] addr  = {POLY_BANK_LEN_LOG2{1'b0}};
   wire [POLY_BANK_LEN_LOG2:0]  addr1 = {1'b0, addr};
   wire [POLY_BANK_LEN_LOG2:0]  addr2 = {1'b1, addr};

   reg addr_del = 1'b0;

   always @(posedge clk_120mhz_i) begin
      if (ce_i) begin
         if (!addr_del) begin
            addr_del <= !addr_del;
            addr     <= {POLY_BANK_LEN_LOG2{1'b0}};
         end else begin
            if (addr == POLY_BANK_LEN-1)
              addr <= {POLY_BANK_LEN_LOG2{1'b0}};
            else
              addr <= addr + 1'b1;
         end
      end else begin // if (ce_i)
         addr_del <= 1'b0;
         addr     <= {POLY_BANK_LEN_LOG2{1'b0}};
      end // else: !if(ce_i)
   end

   rom #(
      .ROMFILE       (`FILE_TAPS0_1),
      .ADDRESS_WIDTH (POLY_BANK_LEN_LOG2+1),
      .DATA_WIDTH    (TAP_WIDTH),
      .ROM_SIZE      (ROM_SIZE)
   ) taps0_1_rom (
      .clk   (clk_120mhz_i),
      .en1   (ce_i),
      .en2   (ce_i),
      .addr1 (addr1),
      .addr2 (addr2),
      .do1   (h0_do),
      .do2   (h1_do)
   );

   rom #(
      .ROMFILE       (`FILE_TAPS2_3),
      .ADDRESS_WIDTH (POLY_BANK_LEN_LOG2+1),
      .DATA_WIDTH    (TAP_WIDTH),
      .ROM_SIZE      (ROM_SIZE)
   ) taps2_3_rom (
      .clk   (clk_120mhz_i),
      .en1   (ce_i),
      .en2   (ce_i),
      .addr1 (addr1),
      .addr2 (addr2),
      .do1   (h2_do),
      .do2   (h3_do)
   );

   rom #(
      .ROMFILE       (`FILE_TAPS4_5),
      .ADDRESS_WIDTH (POLY_BANK_LEN_LOG2+1),
      .DATA_WIDTH    (TAP_WIDTH),
      .ROM_SIZE      (ROM_SIZE)
   ) taps4_5_rom (
      .clk   (clk_120mhz_i),
      .en1   (ce_i),
      .en2   (ce_i),
      .addr1 (addr1),
      .addr2 (addr2),
      .do1   (h4_do),
      .do2   (h5_do)
   );

   rom #(
      .ROMFILE       (`FILE_TAPS6_7),
      .ADDRESS_WIDTH (POLY_BANK_LEN_LOG2+1),
      .DATA_WIDTH    (TAP_WIDTH),
      .ROM_SIZE      (ROM_SIZE)
   ) taps6_7_rom (
      .clk   (clk_120mhz_i),
      .en1   (ce_i),
      .en2   (ce_i),
      .addr1 (addr1),
      .addr2 (addr2),
      .do1   (h6_do),
      .do2   (h7_do)
   );

   rom #(
      .ROMFILE       (`FILE_TAPS8_9),
      .ADDRESS_WIDTH (POLY_BANK_LEN_LOG2+1),
      .DATA_WIDTH    (TAP_WIDTH),
      .ROM_SIZE      (ROM_SIZE)
   ) taps8_9_rom (
      .clk   (clk_120mhz_i),
      .en1   (ce_i),
      .en2   (ce_i),
      .addr1 (addr1),
      .addr2 (addr2),
      .do1   (h8_do),
      .do2   (h9_do)
   );

   rom #(
      .ROMFILE       (`FILE_TAPS10_11),
      .ADDRESS_WIDTH (POLY_BANK_LEN_LOG2+1),
      .DATA_WIDTH    (TAP_WIDTH),
      .ROM_SIZE      (ROM_SIZE)
   ) taps10_11_rom (
      .clk   (clk_120mhz_i),
      .en1   (ce_i),
      .en2   (ce_i),
      .addr1 (addr1),
      .addr2 (addr2),
      .do1   (h10_do),
      .do2   (h11_do)
   );

   rom #(
      .ROMFILE       (`FILE_TAPS12_13),
      .ADDRESS_WIDTH (POLY_BANK_LEN_LOG2+1),
      .DATA_WIDTH    (TAP_WIDTH),
      .ROM_SIZE      (ROM_SIZE)
   ) taps12_13_rom (
      .clk   (clk_120mhz_i),
      .en1   (ce_i),
      .en2   (ce_i),
      .addr1 (addr1),
      .addr2 (addr2),
      .do1   (h12_do),
      .do2   (h13_do)
   );

   rom #(
      .ROMFILE       (`FILE_TAPS14_15),
      .ADDRESS_WIDTH (POLY_BANK_LEN_LOG2+1),
      .DATA_WIDTH    (TAP_WIDTH),
      .ROM_SIZE      (ROM_SIZE)
   ) taps14_15_rom (
      .clk   (clk_120mhz_i),
      .en1   (ce_i),
      .en2   (ce_i),
      .addr1 (addr1),
      .addr2 (addr2),
      .do1   (h14_do),
      .do2   (h15_do)
   );

   rom #(
      .ROMFILE       (`FILE_TAPS16_17),
      .ADDRESS_WIDTH (POLY_BANK_LEN_LOG2+1),
      .DATA_WIDTH    (TAP_WIDTH),
      .ROM_SIZE      (ROM_SIZE)
   ) taps16_17_rom (
      .clk   (clk_120mhz_i),
      .en1   (ce_i),
      .en2   (ce_i),
      .addr1 (addr1),
      .addr2 (addr2),
      .do1   (h16_do),
      .do2   (h17_do)
   );

   rom #(
      .ROMFILE       (`FILE_TAPS18_19),
      .ADDRESS_WIDTH (POLY_BANK_LEN_LOG2+1),
      .DATA_WIDTH    (TAP_WIDTH),
      .ROM_SIZE      (ROM_SIZE)
   ) taps18_19_rom (
      .clk   (clk_120mhz_i),
      .en1   (ce_i),
      .en2   (ce_i),
      .addr1 (addr1),
      .addr2 (addr2),
      .do1   (h18_do),
      .do2   (h19_do)
   );

   fir_poly #(
      .M                  (M),
      .M_WIDTH            (M_WIDTH),
      .INPUT_WIDTH        (INPUT_WIDTH),
      .INTERNAL_WIDTH     (INTERNAL_WIDTH),
      .NORM_SHIFT         (NORM_SHIFT),
      .OUTPUT_WIDTH       (OUTPUT_WIDTH),
      .TAP_WIDTH          (TAP_WIDTH),
      .POLY_BANK_LEN      (POLY_BANK_LEN),
      .POLY_BANK_LEN_LOG2 (POLY_BANK_LEN_LOG2)
   ) fir_a (
      .clk_i             (clk_i),
      .clk_120mhz_i      (clk_120mhz_i),
      .clk_2mhz_pos_en_i (clk_2mhz_pos_en_i),
      .ce_i              (ce_i),
      .di_i              (chan_a_di_i),
      .tap_addr          (addr),
      .tap0              (h0_do),
      .tap1              (h1_do),
      .tap2              (h2_do),
      .tap3              (h3_do),
      .tap4              (h4_do),
      .tap5              (h5_do),
      .tap6              (h6_do),
      .tap7              (h7_do),
      .tap8              (h8_do),
      .tap9              (h9_do),
      .tap10             (h10_do),
      .tap11             (h11_do),
      .tap12             (h12_do),
      .tap13             (h13_do),
      .tap14             (h14_do),
      .tap15             (h15_do),
      .tap16             (h16_do),
      .tap17             (h17_do),
      .tap18             (h18_do),
      .tap19             (h19_do),
      .do_o              (chan_a_do_o),
      .f0                (chan_a_f0),
      .f1                (chan_a_f1),
      .f2                (chan_a_f2),
      .f3                (chan_a_f3),
      .f4                (chan_a_f4),
      .f5                (chan_a_f5),
      .f6                (chan_a_f6),
      .f7                (chan_a_f7),
      .f8                (chan_a_f8),
      .f9                (chan_a_f9),
      .f10               (chan_a_f10),
      .f11               (chan_a_f11),
      .f12               (chan_a_f12),
      .f13               (chan_a_f13),
      .f14               (chan_a_f14),
      .f15               (chan_a_f15),
      .f16               (chan_a_f16),
      .f17               (chan_a_f17),
      .f18               (chan_a_f18),
      .f19               (chan_a_f19),
      .d_2mhz_0          (chan_a_d_2mhz_0),
      .d_2mhz_1          (chan_a_d_2mhz_1),
      .d_2mhz_2          (chan_a_d_2mhz_2),
      .d_2mhz_3          (chan_a_d_2mhz_3),
      .d_2mhz_4          (chan_a_d_2mhz_4),
      .d_2mhz_5          (chan_a_d_2mhz_5),
      .d_2mhz_6          (chan_a_d_2mhz_6),
      .d_2mhz_7          (chan_a_d_2mhz_7),
      .d_2mhz_8          (chan_a_d_2mhz_8),
      .d_2mhz_9          (chan_a_d_2mhz_9),
      .d_2mhz_10         (chan_a_d_2mhz_10),
      .d_2mhz_11         (chan_a_d_2mhz_11),
      .d_2mhz_12         (chan_a_d_2mhz_12),
      .d_2mhz_13         (chan_a_d_2mhz_13),
      .d_2mhz_14         (chan_a_d_2mhz_14),
      .d_2mhz_15         (chan_a_d_2mhz_15),
      .d_2mhz_16         (chan_a_d_2mhz_16),
      .d_2mhz_17         (chan_a_d_2mhz_17),
      .d_2mhz_18         (chan_a_d_2mhz_18),
      .d_2mhz_19         (chan_a_d_2mhz_19)
   );

   fir_poly #(
      .M                  (M),
      .M_WIDTH            (M_WIDTH),
      .INPUT_WIDTH        (INPUT_WIDTH),
      .INTERNAL_WIDTH     (INTERNAL_WIDTH),
      .NORM_SHIFT         (NORM_SHIFT),
      .OUTPUT_WIDTH       (OUTPUT_WIDTH),
      .TAP_WIDTH          (TAP_WIDTH),
      .POLY_BANK_LEN      (POLY_BANK_LEN),
      .POLY_BANK_LEN_LOG2 (POLY_BANK_LEN_LOG2)
   ) fir_b (
      .clk_i             (clk_i),
      .clk_120mhz_i      (clk_120mhz_i),
      .clk_2mhz_pos_en_i (clk_2mhz_pos_en_i),
      .ce_i              (ce_i),
      .di_i              (chan_b_di_i),
      .tap_addr          (addr),
      .tap0              (h0_do),
      .tap1              (h1_do),
      .tap2              (h2_do),
      .tap3              (h3_do),
      .tap4              (h4_do),
      .tap5              (h5_do),
      .tap6              (h6_do),
      .tap7              (h7_do),
      .tap8              (h8_do),
      .tap9              (h9_do),
      .tap10             (h10_do),
      .tap11             (h11_do),
      .tap12             (h12_do),
      .tap13             (h13_do),
      .tap14             (h14_do),
      .tap15             (h15_do),
      .tap16             (h16_do),
      .tap17             (h17_do),
      .tap18             (h18_do),
      .tap19             (h19_do),
      .do_o              (chan_b_do_o),
      .f0                (chan_b_f0),
      .f1                (chan_b_f1),
      .f2                (chan_b_f2),
      .f3                (chan_b_f3),
      .f4                (chan_b_f4),
      .f5                (chan_b_f5),
      .f6                (chan_b_f6),
      .f7                (chan_b_f7),
      .f8                (chan_b_f8),
      .f9                (chan_b_f9),
      .f10               (chan_b_f10),
      .f11               (chan_b_f11),
      .f12               (chan_b_f12),
      .f13               (chan_b_f13),
      .f14               (chan_b_f14),
      .f15               (chan_b_f15),
      .f16               (chan_b_f16),
      .f17               (chan_b_f17),
      .f18               (chan_b_f18),
      .f19               (chan_b_f19),
      .d_2mhz_0          (chan_b_d_2mhz_0),
      .d_2mhz_1          (chan_b_d_2mhz_1),
      .d_2mhz_2          (chan_b_d_2mhz_2),
      .d_2mhz_3          (chan_b_d_2mhz_3),
      .d_2mhz_4          (chan_b_d_2mhz_4),
      .d_2mhz_5          (chan_b_d_2mhz_5),
      .d_2mhz_6          (chan_b_d_2mhz_6),
      .d_2mhz_7          (chan_b_d_2mhz_7),
      .d_2mhz_8          (chan_b_d_2mhz_8),
      .d_2mhz_9          (chan_b_d_2mhz_9),
      .d_2mhz_10         (chan_b_d_2mhz_10),
      .d_2mhz_11         (chan_b_d_2mhz_11),
      .d_2mhz_12         (chan_b_d_2mhz_12),
      .d_2mhz_13         (chan_b_d_2mhz_13),
      .d_2mhz_14         (chan_b_d_2mhz_14),
      .d_2mhz_15         (chan_b_d_2mhz_15),
      .d_2mhz_16         (chan_b_d_2mhz_16),
      .d_2mhz_17         (chan_b_d_2mhz_17),
      .d_2mhz_18         (chan_b_d_2mhz_18),
      .d_2mhz_19         (chan_b_d_2mhz_19)
   );

endmodule // fir


`ifdef SIMULATE

`include "dsp.v"
`include "DSP48E1.v"
`include "BRAM_TDP_MACRO.v"
`include "RAMB18E1.v"
`include "PLLE2_BASE.v"
`include "PLLE2_ADV.v"
`include "glbl.v"

`timescale 1ns/1ps
module fir_tb;

   localparam M                  = 20; /* downsampling factor */
   localparam M_WIDTH            = 5;
   localparam INPUT_WIDTH        = 12;
   localparam INTERNAL_WIDTH     = 39;
   localparam NORM_SHIFT         = 4;
   localparam OUTPUT_WIDTH       = 14;
   localparam TAP_WIDTH          = 16;
   localparam POLY_BANK_LEN      = 60; /* number of taps in each polyphase decomposition filter bank */
   localparam POLY_BANK_LEN_LOG2 = 6;
   localparam ROM_SIZE           = 128;
   localparam ADC_DATA_WIDTH     = 12;
   localparam SAMPLE_LEN         = 10000;

   reg clk;
   integer ctr, ctr_del, f;
   reg signed [INPUT_WIDTH-1:0] chan_a [0:SAMPLE_LEN-1];
   reg signed [INPUT_WIDTH-1:0] chan_b [0:SAMPLE_LEN-1];
   wire signed [OUTPUT_WIDTH-1:0] data_o;

   wire signed [INPUT_WIDTH-1:0]  chan_a_di = chan_a[ctr];
   wire signed [INPUT_WIDTH-1:0]  chan_b_di = chan_b[ctr];

   wire                 clk_120mhz;
   wire                 pll_lock;
   wire                 clk_fb;

   reg                  clk_2mhz_pos_en = 1'b1;
   reg                  clk_2mhz_neg_en = 1'b1;
   reg [4:0]            clk_2mhz_ctr    = 5'd0;
   reg                  clk_4mhz_pos_en = 1'b1;
   reg [3:0]            clk_4mhz_ctr    = 5'd0;

   always @(posedge clk) begin
      if (clk_4mhz_ctr == 4'd9) begin
         clk_4mhz_pos_en <= 1'b1;
         clk_4mhz_ctr    <= 4'd0;
      end else begin
         clk_4mhz_pos_en <= 1'b0;
         clk_4mhz_ctr    <= clk_4mhz_ctr + 1'b1;
      end

      if (clk_2mhz_ctr == 5'd9) begin
         clk_2mhz_neg_en <= 1'b1;
         clk_2mhz_pos_en <= 1'b0;
         clk_2mhz_ctr    <= clk_2mhz_ctr + 1'b1;
      end else if (clk_2mhz_ctr == 5'd19) begin
         clk_2mhz_neg_en <= 1'b0;
         clk_2mhz_pos_en <= 1'b1;
         clk_2mhz_ctr    <= 5'd0;
      end else begin
         clk_2mhz_neg_en <= 1'b0;
         clk_2mhz_pos_en <= 1'b0;
         clk_2mhz_ctr    <= clk_2mhz_ctr + 1'b1;
      end
   end

   PLLE2_BASE #(
      .CLKFBOUT_MULT  (24),
      .DIVCLK_DIVIDE  (1),
      .CLKOUT0_DIVIDE (8),
      .CLKIN1_PERIOD  (25)
   ) PLLE2_BASE_120mhz (
      .CLKOUT0  (clk_120mhz),
      .LOCKED   (pll_lock),
      .CLKIN1   (clk),
      .RST      (1'b0),
      .CLKFBOUT (clk_fb),
      .CLKFBIN  (clk_fb)
   );

   initial begin
      $dumpfile("tb/fir.vcd");
      $dumpvars(0, fir_tb);
      $dumpvars(0, chan_a_di);
      $dumpvars(0, chan_b_di);

      f = $fopen("tb/sample_out_verilog.txt", "w");

      $readmemh("tb/sample_in.hex", chan_a);
      $readmemh("tb/sample_in.hex", chan_b);
      clk = 1'b0;
      ctr = 0;

      #100000 $finish;
   end

   always #12.5 clk = !clk;

   always @(posedge clk) begin
      // if (pll_lock) begin
      //    ctr_del <= 0;
      // end else begin
      //    ctr_del <= ctr_del + 1;
      // end
      if (pll_lock)
        ctr <= ctr + 1'b1;
   end

   always @(posedge clk) begin
      if (clk_2mhz_pos_en)
        $fwrite(f, "%d\n", $signed(chan_a_filtered));
   end

   wire [OUTPUT_WIDTH-1:0]         chan_a_filtered;
   wire [OUTPUT_WIDTH-1:0]         chan_b_filtered;

   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f0  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f1  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f2  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f3  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f4  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f5  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f6  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f7  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f8  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f9  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f10 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f11 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f12 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f13 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f14 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f15 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f16 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f17 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f18 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_a_f19 = {INTERNAL_WIDTH{1'b0}};

   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f0  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f1  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f2  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f3  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f4  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f5  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f6  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f7  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f8  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f9  = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f10 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f11 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f12 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f13 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f14 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f15 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f16 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f17 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f18 = {INTERNAL_WIDTH{1'b0}};
   reg signed [INTERNAL_WIDTH-1:0] fir_chan_b_f19 = {INTERNAL_WIDTH{1'b0}};

   wire [POLY_BANK_LEN_LOG2-1:0]   fir_tap_addr;

   wire signed [TAP_WIDTH-1:0]     fir_tap0;
   wire signed [TAP_WIDTH-1:0]     fir_tap1;
   wire signed [TAP_WIDTH-1:0]     fir_tap2;
   wire signed [TAP_WIDTH-1:0]     fir_tap3;
   wire signed [TAP_WIDTH-1:0]     fir_tap4;
   wire signed [TAP_WIDTH-1:0]     fir_tap5;
   wire signed [TAP_WIDTH-1:0]     fir_tap6;
   wire signed [TAP_WIDTH-1:0]     fir_tap7;
   wire signed [TAP_WIDTH-1:0]     fir_tap8;
   wire signed [TAP_WIDTH-1:0]     fir_tap9;
   wire signed [TAP_WIDTH-1:0]     fir_tap10;
   wire signed [TAP_WIDTH-1:0]     fir_tap11;
   wire signed [TAP_WIDTH-1:0]     fir_tap12;
   wire signed [TAP_WIDTH-1:0]     fir_tap13;
   wire signed [TAP_WIDTH-1:0]     fir_tap14;
   wire signed [TAP_WIDTH-1:0]     fir_tap15;
   wire signed [TAP_WIDTH-1:0]     fir_tap16;
   wire signed [TAP_WIDTH-1:0]     fir_tap17;
   wire signed [TAP_WIDTH-1:0]     fir_tap18;
   wire signed [TAP_WIDTH-1:0]     fir_tap19;

   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_0;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_1;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_2;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_3;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_4;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_5;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_6;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_7;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_8;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_9;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_10;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_11;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_12;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_13;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_14;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_15;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_16;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_17;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_18;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_19;

   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_0;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_1;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_2;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_3;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_4;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_5;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_6;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_7;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_8;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_9;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_10;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_11;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_12;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_13;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_14;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_15;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_16;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_17;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_18;
   wire signed [OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_19;

   fir #(
      .M                  (M),
      .M_WIDTH            (M_WIDTH),
      .INPUT_WIDTH        (ADC_DATA_WIDTH),
      .INTERNAL_WIDTH     (INTERNAL_WIDTH),
      .NORM_SHIFT         (NORM_SHIFT),
      .OUTPUT_WIDTH       (OUTPUT_WIDTH),
      .TAP_WIDTH          (TAP_WIDTH),
      .POLY_BANK_LEN      (POLY_BANK_LEN),
      .POLY_BANK_LEN_LOG2 (POLY_BANK_LEN_LOG2),
      .ROM_SIZE           (ROM_SIZE)
   ) fir (
      .clk_i             (clk),
      .clk_120mhz_i      (clk_120mhz),
      .clk_2mhz_pos_en_i (clk_2mhz_pos_en),
      .ce_i              (pll_lock),
      .chan_a_di_i       (chan_a[ctr]),
      .chan_b_di_i       (chan_b[ctr]),
      .chan_a_do_o       (chan_a_filtered),
      .chan_b_do_o       (chan_b_filtered),
      .chan_a_f0         (fir_chan_a_f0),
      .chan_a_f1         (fir_chan_a_f1),
      .chan_a_f2         (fir_chan_a_f2),
      .chan_a_f3         (fir_chan_a_f3),
      .chan_a_f4         (fir_chan_a_f4),
      .chan_a_f5         (fir_chan_a_f5),
      .chan_a_f6         (fir_chan_a_f6),
      .chan_a_f7         (fir_chan_a_f7),
      .chan_a_f8         (fir_chan_a_f8),
      .chan_a_f9         (fir_chan_a_f9),
      .chan_a_f10        (fir_chan_a_f10),
      .chan_a_f11        (fir_chan_a_f11),
      .chan_a_f12        (fir_chan_a_f12),
      .chan_a_f13        (fir_chan_a_f13),
      .chan_a_f14        (fir_chan_a_f14),
      .chan_a_f15        (fir_chan_a_f15),
      .chan_a_f16        (fir_chan_a_f16),
      .chan_a_f17        (fir_chan_a_f17),
      .chan_a_f18        (fir_chan_a_f18),
      .chan_a_f19        (fir_chan_a_f19),
      .chan_b_f0         (fir_chan_b_f0),
      .chan_b_f1         (fir_chan_b_f1),
      .chan_b_f2         (fir_chan_b_f2),
      .chan_b_f3         (fir_chan_b_f3),
      .chan_b_f4         (fir_chan_b_f4),
      .chan_b_f5         (fir_chan_b_f5),
      .chan_b_f6         (fir_chan_b_f6),
      .chan_b_f7         (fir_chan_b_f7),
      .chan_b_f8         (fir_chan_b_f8),
      .chan_b_f9         (fir_chan_b_f9),
      .chan_b_f10        (fir_chan_b_f10),
      .chan_b_f11        (fir_chan_b_f11),
      .chan_b_f12        (fir_chan_b_f12),
      .chan_b_f13        (fir_chan_b_f13),
      .chan_b_f14        (fir_chan_b_f14),
      .chan_b_f15        (fir_chan_b_f15),
      .chan_b_f16        (fir_chan_b_f16),
      .chan_b_f17        (fir_chan_b_f17),
      .chan_b_f18        (fir_chan_b_f18),
      .chan_b_f19        (fir_chan_b_f19),
      .tap_addr          (fir_tap_addr),
      .tap0              (fir_tap0),
      .tap1              (fir_tap1),
      .tap2              (fir_tap2),
      .tap3              (fir_tap3),
      .tap4              (fir_tap4),
      .tap5              (fir_tap5),
      .tap6              (fir_tap6),
      .tap7              (fir_tap7),
      .tap8              (fir_tap8),
      .tap9              (fir_tap9),
      .tap10             (fir_tap10),
      .tap11             (fir_tap11),
      .tap12             (fir_tap12),
      .tap13             (fir_tap13),
      .tap14             (fir_tap14),
      .tap15             (fir_tap15),
      .tap16             (fir_tap16),
      .tap17             (fir_tap17),
      .tap18             (fir_tap18),
      .tap19             (fir_tap19),
      .chan_a_d_2mhz_0   (fir_chan_a_d_2mhz_0),
      .chan_a_d_2mhz_1   (fir_chan_a_d_2mhz_1),
      .chan_a_d_2mhz_2   (fir_chan_a_d_2mhz_2),
      .chan_a_d_2mhz_3   (fir_chan_a_d_2mhz_3),
      .chan_a_d_2mhz_4   (fir_chan_a_d_2mhz_4),
      .chan_a_d_2mhz_5   (fir_chan_a_d_2mhz_5),
      .chan_a_d_2mhz_6   (fir_chan_a_d_2mhz_6),
      .chan_a_d_2mhz_7   (fir_chan_a_d_2mhz_7),
      .chan_a_d_2mhz_8   (fir_chan_a_d_2mhz_8),
      .chan_a_d_2mhz_9   (fir_chan_a_d_2mhz_9),
      .chan_a_d_2mhz_10  (fir_chan_a_d_2mhz_10),
      .chan_a_d_2mhz_11  (fir_chan_a_d_2mhz_11),
      .chan_a_d_2mhz_12  (fir_chan_a_d_2mhz_12),
      .chan_a_d_2mhz_13  (fir_chan_a_d_2mhz_13),
      .chan_a_d_2mhz_14  (fir_chan_a_d_2mhz_14),
      .chan_a_d_2mhz_15  (fir_chan_a_d_2mhz_15),
      .chan_a_d_2mhz_16  (fir_chan_a_d_2mhz_16),
      .chan_a_d_2mhz_17  (fir_chan_a_d_2mhz_17),
      .chan_a_d_2mhz_18  (fir_chan_a_d_2mhz_18),
      .chan_a_d_2mhz_19  (fir_chan_a_d_2mhz_19),
      .chan_b_d_2mhz_0   (fir_chan_b_d_2mhz_0),
      .chan_b_d_2mhz_1   (fir_chan_b_d_2mhz_1),
      .chan_b_d_2mhz_2   (fir_chan_b_d_2mhz_2),
      .chan_b_d_2mhz_3   (fir_chan_b_d_2mhz_3),
      .chan_b_d_2mhz_4   (fir_chan_b_d_2mhz_4),
      .chan_b_d_2mhz_5   (fir_chan_b_d_2mhz_5),
      .chan_b_d_2mhz_6   (fir_chan_b_d_2mhz_6),
      .chan_b_d_2mhz_7   (fir_chan_b_d_2mhz_7),
      .chan_b_d_2mhz_8   (fir_chan_b_d_2mhz_8),
      .chan_b_d_2mhz_9   (fir_chan_b_d_2mhz_9),
      .chan_b_d_2mhz_10  (fir_chan_b_d_2mhz_10),
      .chan_b_d_2mhz_11  (fir_chan_b_d_2mhz_11),
      .chan_b_d_2mhz_12  (fir_chan_b_d_2mhz_12),
      .chan_b_d_2mhz_13  (fir_chan_b_d_2mhz_13),
      .chan_b_d_2mhz_14  (fir_chan_b_d_2mhz_14),
      .chan_b_d_2mhz_15  (fir_chan_b_d_2mhz_15),
      .chan_b_d_2mhz_16  (fir_chan_b_d_2mhz_16),
      .chan_b_d_2mhz_17  (fir_chan_b_d_2mhz_17),
      .chan_b_d_2mhz_18  (fir_chan_b_d_2mhz_18),
      .chan_b_d_2mhz_19  (fir_chan_b_d_2mhz_19)
   );

   localparam DSP_A_DATA_WIDTH = 25;
   localparam DSP_B_DATA_WIDTH = 18;
   localparam DSP_P_DATA_WIDTH = 48;

   reg                                dsp_acc;
   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp1_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp1_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp1_p;

   always @(*) begin
      if (pll_lock) begin
         // TODO if the acc is too slow, compute the clock before and
         // register it.
         dsp_acc      = (fir_tap_addr != {POLY_BANK_LEN_LOG2{1'b0}});
         dsp1_a        = $signed(fir_tap0);
         dsp1_b        = $signed(fir_chan_a_d_2mhz_0);
         fir_chan_a_f0 = dsp1_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp1 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp1_a),
      .b     (dsp1_b),
      .p     (dsp1_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp2_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp2_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp2_p;

   always @(*) begin
      if (pll_lock) begin
         dsp2_a        = $signed(fir_tap1);
         dsp2_b        = $signed(fir_chan_a_d_2mhz_1);
         fir_chan_a_f1 = dsp2_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp2 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp2_a),
      .b     (dsp2_b),
      .p     (dsp2_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp3_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp3_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp3_p;

   always @(*) begin
      if (pll_lock) begin
         dsp3_a        = $signed(fir_tap2);
         dsp3_b        = $signed(fir_chan_a_d_2mhz_2);
         fir_chan_a_f2 = dsp3_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp3 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp3_a),
      .b     (dsp3_b),
      .p     (dsp3_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp4_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp4_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp4_p;

   always @(*) begin
      if (pll_lock) begin
         dsp4_a        = $signed(fir_tap3);
         dsp4_b        = $signed(fir_chan_a_d_2mhz_3);
         fir_chan_a_f3 = dsp4_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp4 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp4_a),
      .b     (dsp4_b),
      .p     (dsp4_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp5_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp5_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp5_p;

   always @(*) begin
      if (pll_lock) begin
         dsp5_a        = $signed(fir_tap4);
         dsp5_b        = $signed(fir_chan_a_d_2mhz_4);
         fir_chan_a_f4 = dsp5_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp5 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp5_a),
      .b     (dsp5_b),
      .p     (dsp5_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp6_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp6_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp6_p;

   always @(*) begin
      if (pll_lock) begin
         dsp6_a        = $signed(fir_tap5);
         dsp6_b        = $signed(fir_chan_a_d_2mhz_5);
         fir_chan_a_f5 = dsp6_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp6 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp6_a),
      .b     (dsp6_b),
      .p     (dsp6_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp7_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp7_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp7_p;

   always @(*) begin
      if (pll_lock) begin
         dsp7_a        = $signed(fir_tap6);
         dsp7_b        = $signed(fir_chan_a_d_2mhz_6);
         fir_chan_a_f6 = dsp7_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp7 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp7_a),
      .b     (dsp7_b),
      .p     (dsp7_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp8_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp8_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp8_p;

   always @(*) begin
      if (pll_lock) begin
         dsp8_a        = $signed(fir_tap7);
         dsp8_b        = $signed(fir_chan_a_d_2mhz_7);
         fir_chan_a_f7 = dsp8_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp8 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp8_a),
      .b     (dsp8_b),
      .p     (dsp8_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp9_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp9_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp9_p;

   always @(*) begin
      if (pll_lock) begin
         dsp9_a        = $signed(fir_tap8);
         dsp9_b        = $signed(fir_chan_a_d_2mhz_8);
         fir_chan_a_f8 = dsp9_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp9 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp9_a),
      .b     (dsp9_b),
      .p     (dsp9_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp10_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp10_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp10_p;

   always @(*) begin
      if (pll_lock) begin
         dsp10_a        = $signed(fir_tap9);
         dsp10_b        = $signed(fir_chan_a_d_2mhz_9);
         fir_chan_a_f9  = dsp10_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp10 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp10_a),
      .b     (dsp10_b),
      .p     (dsp10_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp11_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp11_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp11_p;

   always @(*) begin
      if (pll_lock) begin
         dsp11_a        = $signed(fir_tap10);
         dsp11_b        = $signed(fir_chan_a_d_2mhz_10);
         fir_chan_a_f10 = dsp11_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp11 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp11_a),
      .b     (dsp11_b),
      .p     (dsp11_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp12_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp12_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp12_p;

   always @(*) begin
      if (pll_lock) begin
         dsp12_a        = $signed(fir_tap11);
         dsp12_b        = $signed(fir_chan_a_d_2mhz_11);
         fir_chan_a_f11 = dsp12_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp12 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp12_a),
      .b     (dsp12_b),
      .p     (dsp12_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp13_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp13_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp13_p;

   always @(*) begin
      if (pll_lock) begin
         dsp13_a        = $signed(fir_tap12);
         dsp13_b        = $signed(fir_chan_a_d_2mhz_12);
         fir_chan_a_f12 = dsp13_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp13 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp13_a),
      .b     (dsp13_b),
      .p     (dsp13_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp14_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp14_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp14_p;

   always @(*) begin
      if (pll_lock) begin
         dsp14_a        = $signed(fir_tap13);
         dsp14_b        = $signed(fir_chan_a_d_2mhz_13);
         fir_chan_a_f13 = dsp14_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp14 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp14_a),
      .b     (dsp14_b),
      .p     (dsp14_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp15_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp15_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp15_p;

   always @(*) begin
      if (pll_lock) begin
         dsp15_a        = $signed(fir_tap14);
         dsp15_b        = $signed(fir_chan_a_d_2mhz_14);
         fir_chan_a_f14 = dsp15_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp15 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp15_a),
      .b     (dsp15_b),
      .p     (dsp15_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp16_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp16_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp16_p;

   always @(*) begin
      if (pll_lock) begin
         dsp16_a        = $signed(fir_tap15);
         dsp16_b        = $signed(fir_chan_a_d_2mhz_15);
         fir_chan_a_f15 = dsp16_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp16 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp16_a),
      .b     (dsp16_b),
      .p     (dsp16_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp17_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp17_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp17_p;

   always @(*) begin
      if (pll_lock) begin
         dsp17_a        = $signed(fir_tap16);
         dsp17_b        = $signed(fir_chan_a_d_2mhz_16);
         fir_chan_a_f16 = dsp17_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp17 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp17_a),
      .b     (dsp17_b),
      .p     (dsp17_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp18_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp18_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp18_p;

   always @(*) begin
      if (pll_lock) begin
         dsp18_a        = $signed(fir_tap17);
         dsp18_b        = $signed(fir_chan_a_d_2mhz_17);
         fir_chan_a_f17 = dsp18_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp18 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp18_a),
      .b     (dsp18_b),
      .p     (dsp18_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp19_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp19_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp19_p;

   always @(*) begin
      if (pll_lock) begin
         dsp19_a        = $signed(fir_tap18);
         dsp19_b        = $signed(fir_chan_a_d_2mhz_18);
         fir_chan_a_f18 = dsp19_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp19 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp19_a),
      .b     (dsp19_b),
      .p     (dsp19_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp20_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp20_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp20_p;

   always @(*) begin
      if (pll_lock) begin
         dsp20_a        = $signed(fir_tap19);
         dsp20_b        = $signed(fir_chan_a_d_2mhz_19);
         fir_chan_a_f19 = dsp20_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp20 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp20_a),
      .b     (dsp20_b),
      .p     (dsp20_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp21_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp21_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp21_p;

   always @(*) begin
      if (pll_lock) begin
         dsp21_a        = $signed(fir_tap0);
         dsp21_b        = $signed(fir_chan_b_d_2mhz_0);
         fir_chan_b_f0  = dsp21_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp21 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp21_a),
      .b     (dsp21_b),
      .p     (dsp21_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp22_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp22_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp22_p;

   always @(*) begin
      if (pll_lock) begin
         dsp22_a        = $signed(fir_tap1);
         dsp22_b        = $signed(fir_chan_b_d_2mhz_1);
         fir_chan_b_f1  = dsp22_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp22 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp22_a),
      .b     (dsp22_b),
      .p     (dsp22_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp23_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp23_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp23_p;

   always @(*) begin
      if (pll_lock) begin
         dsp23_a        = $signed(fir_tap2);
         dsp23_b        = $signed(fir_chan_b_d_2mhz_2);
         fir_chan_b_f2  = dsp23_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp23 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp23_a),
      .b     (dsp23_b),
      .p     (dsp23_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp24_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp24_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp24_p;

   always @(*) begin
      if (pll_lock) begin
         dsp24_a        = $signed(fir_tap3);
         dsp24_b        = $signed(fir_chan_b_d_2mhz_3);
         fir_chan_b_f3  = dsp24_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp24 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp24_a),
      .b     (dsp24_b),
      .p     (dsp24_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp25_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp25_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp25_p;

   always @(*) begin
      if (pll_lock) begin
         dsp25_a        = $signed(fir_tap4);
         dsp25_b        = $signed(fir_chan_b_d_2mhz_4);
         fir_chan_b_f4  = dsp25_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp25 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp25_a),
      .b     (dsp25_b),
      .p     (dsp25_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp26_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp26_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp26_p;

   always @(*) begin
      if (pll_lock) begin
         dsp26_a        = $signed(fir_tap5);
         dsp26_b        = $signed(fir_chan_b_d_2mhz_5);
         fir_chan_b_f5  = dsp26_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp26 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp26_a),
      .b     (dsp26_b),
      .p     (dsp26_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp27_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp27_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp27_p;

   always @(*) begin
      if (pll_lock) begin
         dsp27_a        = $signed(fir_tap6);
         dsp27_b        = $signed(fir_chan_b_d_2mhz_6);
         fir_chan_b_f6  = dsp27_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp27 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp27_a),
      .b     (dsp27_b),
      .p     (dsp27_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp28_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp28_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp28_p;

   always @(*) begin
      if (pll_lock) begin
         dsp28_a        = $signed(fir_tap7);
         dsp28_b        = $signed(fir_chan_b_d_2mhz_7);
         fir_chan_b_f7  = dsp28_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp28 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp28_a),
      .b     (dsp28_b),
      .p     (dsp28_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp29_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp29_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp29_p;

   always @(*) begin
      if (pll_lock) begin
         dsp29_a        = $signed(fir_tap8);
         dsp29_b        = $signed(fir_chan_b_d_2mhz_8);
         fir_chan_b_f8  = dsp29_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp29 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp29_a),
      .b     (dsp29_b),
      .p     (dsp29_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp30_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp30_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp30_p;

   always @(*) begin
      if (pll_lock) begin
         dsp30_a        = $signed(fir_tap9);
         dsp30_b        = $signed(fir_chan_b_d_2mhz_9);
         fir_chan_b_f9  = dsp30_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp30 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp30_a),
      .b     (dsp30_b),
      .p     (dsp30_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp31_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp31_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp31_p;

   always @(*) begin
      if (pll_lock) begin
         dsp31_a        = $signed(fir_tap10);
         dsp31_b        = $signed(fir_chan_b_d_2mhz_10);
         fir_chan_b_f10 = dsp31_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp31 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp31_a),
      .b     (dsp31_b),
      .p     (dsp31_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp32_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp32_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp32_p;

   always @(*) begin
      if (pll_lock) begin
         dsp32_a        = $signed(fir_tap11);
         dsp32_b        = $signed(fir_chan_b_d_2mhz_11);
         fir_chan_b_f11 = dsp32_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp32 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp32_a),
      .b     (dsp32_b),
      .p     (dsp32_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp33_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp33_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp33_p;

   always @(*) begin
      if (pll_lock) begin
         dsp33_a        = $signed(fir_tap12);
         dsp33_b        = $signed(fir_chan_b_d_2mhz_12);
         fir_chan_b_f12 = dsp33_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp33 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp33_a),
      .b     (dsp33_b),
      .p     (dsp33_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp34_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp34_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp34_p;

   always @(*) begin
      if (pll_lock) begin
         dsp34_a        = $signed(fir_tap13);
         dsp34_b        = $signed(fir_chan_b_d_2mhz_13);
         fir_chan_b_f13 = dsp34_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp34 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp34_a),
      .b     (dsp34_b),
      .p     (dsp34_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp35_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp35_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp35_p;

   always @(*) begin
      if (pll_lock) begin
         dsp35_a        = $signed(fir_tap14);
         dsp35_b        = $signed(fir_chan_b_d_2mhz_14);
         fir_chan_b_f14 = dsp35_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp35 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp35_a),
      .b     (dsp35_b),
      .p     (dsp35_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp36_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp36_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp36_p;

   always @(*) begin
      if (pll_lock) begin
         dsp36_a        = $signed(fir_tap15);
         dsp36_b        = $signed(fir_chan_b_d_2mhz_15);
         fir_chan_b_f15 = dsp36_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp36 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp36_a),
      .b     (dsp36_b),
      .p     (dsp36_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp37_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp37_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp37_p;

   always @(*) begin
      if (pll_lock) begin
         dsp37_a        = $signed(fir_tap16);
         dsp37_b        = $signed(fir_chan_b_d_2mhz_16);
         fir_chan_b_f16 = dsp37_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp37 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp37_a),
      .b     (dsp37_b),
      .p     (dsp37_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp38_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp38_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp38_p;

   always @(*) begin
      if (pll_lock) begin
         dsp38_a        = $signed(fir_tap17);
         dsp38_b        = $signed(fir_chan_b_d_2mhz_17);
         fir_chan_b_f17 = dsp38_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp38 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp38_a),
      .b     (dsp38_b),
      .p     (dsp38_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp39_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp39_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp39_p;

   always @(*) begin
      if (pll_lock) begin
         dsp39_a        = $signed(fir_tap18);
         dsp39_b        = $signed(fir_chan_b_d_2mhz_18);
         fir_chan_b_f18 = dsp39_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp39 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp39_a),
      .b     (dsp39_b),
      .p     (dsp39_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp40_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp40_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp40_p;

   always @(*) begin
      if (pll_lock) begin
         dsp40_a        = $signed(fir_tap19);
         dsp40_b        = $signed(fir_chan_b_d_2mhz_19);
         fir_chan_b_f19 = dsp40_p[INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp40 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp40_a),
      .b     (dsp40_b),
      .p     (dsp40_p)
   );

   // fir_poly #(
   //    .M          (M),
   //    .M_LG       (M_LG),
   //    .IW         (IW),
   //    .DW         (DW),
   //    .TAPW       (TAPW),
   //    .TAP_LEN    (TAP_LEN),
   //    .TAP_LEN_LG (TAP_LEN_LG)
   // ) tb (
   //    .clk_i        (clk),
   //    .clk_120mhz_i (clk_120mhz),
   //    .pll_lock_i   (pll_lock),
   //    .ce_i         (1'b1),
   //    .di_i         (data[ctr_del]),
   //    .do_o         (data_o)
   // );

endmodule // fir_tb
`endif
// Local Variables:
// flycheck-verilator-include-path:("/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unimacro/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unisims/")
// End:
