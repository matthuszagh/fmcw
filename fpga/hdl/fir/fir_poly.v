`default_nettype none

`include "decimate.v"
`include "rom.v"

module fir_poly #(
   parameter M                  = 20, /* downsampling factor */
   parameter M_WIDTH            = 5,
   parameter INPUT_WIDTH        = 12,
   parameter INTERNAL_WIDTH     = 39,
   parameter NORM_SHIFT         = 4,
   parameter OUTPUT_WIDTH       = 14,
   parameter TAP_WIDTH          = 16,
   parameter POLY_BANK_LEN      = 60, /* number of taps in each polyphase decomposition filter bank */
   parameter POLY_BANK_LEN_LOG2 = 6
) (
   input wire                           clk_i,
   input wire                           clk_120mhz_i,
   input wire                           clk_2mhz_pos_en_i,
   input wire                           ce_i,
   input wire signed [INPUT_WIDTH-1:0]  di_i,
   input wire [POLY_BANK_LEN_LOG2-1:0]  tap_addr,
   input wire signed [TAP_WIDTH-1:0]    tap0,
   input wire signed [TAP_WIDTH-1:0]    tap1,
   input wire signed [TAP_WIDTH-1:0]    tap2,
   input wire signed [TAP_WIDTH-1:0]    tap3,
   input wire signed [TAP_WIDTH-1:0]    tap4,
   input wire signed [TAP_WIDTH-1:0]    tap5,
   input wire signed [TAP_WIDTH-1:0]    tap6,
   input wire signed [TAP_WIDTH-1:0]    tap7,
   input wire signed [TAP_WIDTH-1:0]    tap8,
   input wire signed [TAP_WIDTH-1:0]    tap9,
   input wire signed [TAP_WIDTH-1:0]    tap10,
   input wire signed [TAP_WIDTH-1:0]    tap11,
   input wire signed [TAP_WIDTH-1:0]    tap12,
   input wire signed [TAP_WIDTH-1:0]    tap13,
   input wire signed [TAP_WIDTH-1:0]    tap14,
   input wire signed [TAP_WIDTH-1:0]    tap15,
   input wire signed [TAP_WIDTH-1:0]    tap16,
   input wire signed [TAP_WIDTH-1:0]    tap17,
   input wire signed [TAP_WIDTH-1:0]    tap18,
   input wire signed [TAP_WIDTH-1:0]    tap19,
   output reg signed [OUTPUT_WIDTH-1:0] do_o = {OUTPUT_WIDTH{1'b0}},

   // DSP I/O
   input wire signed [INTERNAL_WIDTH-1:0] f0,
   input wire signed [INTERNAL_WIDTH-1:0] f1,
   input wire signed [INTERNAL_WIDTH-1:0] f2,
   input wire signed [INTERNAL_WIDTH-1:0] f3,
   input wire signed [INTERNAL_WIDTH-1:0] f4,
   input wire signed [INTERNAL_WIDTH-1:0] f5,
   input wire signed [INTERNAL_WIDTH-1:0] f6,
   input wire signed [INTERNAL_WIDTH-1:0] f7,
   input wire signed [INTERNAL_WIDTH-1:0] f8,
   input wire signed [INTERNAL_WIDTH-1:0] f9,
   input wire signed [INTERNAL_WIDTH-1:0] f10,
   input wire signed [INTERNAL_WIDTH-1:0] f11,
   input wire signed [INTERNAL_WIDTH-1:0] f12,
   input wire signed [INTERNAL_WIDTH-1:0] f13,
   input wire signed [INTERNAL_WIDTH-1:0] f14,
   input wire signed [INTERNAL_WIDTH-1:0] f15,
   input wire signed [INTERNAL_WIDTH-1:0] f16,
   input wire signed [INTERNAL_WIDTH-1:0] f17,
   input wire signed [INTERNAL_WIDTH-1:0] f18,
   input wire signed [INTERNAL_WIDTH-1:0] f19,

   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_0,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_1,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_2,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_3,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_4,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_5,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_6,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_7,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_8,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_9,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_10,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_11,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_12,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_13,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_14,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_15,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_16,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_17,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_18,
   output wire signed [OUTPUT_WIDTH-1:0]  d_2mhz_19
);

   assign d_2mhz_0  = d_2mhz[0];
   assign d_2mhz_1  = d_2mhz[1];
   assign d_2mhz_2  = d_2mhz[2];
   assign d_2mhz_3  = d_2mhz[3];
   assign d_2mhz_4  = d_2mhz[4];
   assign d_2mhz_5  = d_2mhz[5];
   assign d_2mhz_6  = d_2mhz[6];
   assign d_2mhz_7  = d_2mhz[7];
   assign d_2mhz_8  = d_2mhz[8];
   assign d_2mhz_9  = d_2mhz[9];
   assign d_2mhz_10 = d_2mhz[10];
   assign d_2mhz_11 = d_2mhz[11];
   assign d_2mhz_12 = d_2mhz[12];
   assign d_2mhz_13 = d_2mhz[13];
   assign d_2mhz_14 = d_2mhz[14];
   assign d_2mhz_15 = d_2mhz[15];
   assign d_2mhz_16 = d_2mhz[16];
   assign d_2mhz_17 = d_2mhz[17];
   assign d_2mhz_18 = d_2mhz[18];
   assign d_2mhz_19 = d_2mhz[19];

   function [OUTPUT_WIDTH-1:0] trunc_to_output(input [INTERNAL_WIDTH-1:0] expr);
      trunc_to_output = expr[OUTPUT_WIDTH-1:0];
   endfunction // trunc_to_output

   // Decimate signals.
   genvar                               i;
   integer                              j;
   reg signed [OUTPUT_WIDTH-1:0]        fsr [0:M-2];
   wire signed [OUTPUT_WIDTH-1:0]       d_2mhz [0:M-1];

   initial begin
      for (j=0; j<M-1; j=j+1) begin
         fsr[j] = {OUTPUT_WIDTH{1'b0}};
      end
   end

   always @(posedge clk_i) begin
      if (ce_i) begin
         fsr[0] <= di_i;
         for (j=1; j<M-1; j=j+1) begin
            fsr[j] <= fsr[j-1];
         end
      end else begin
         for (j=0; j<M-1; j=j+1) begin
            fsr[j] <= {OUTPUT_WIDTH{1'b0}};
         end
      end
   end

   decimate #(
      .M    (M),
      .M_LG (M_WIDTH),
      .DW   (OUTPUT_WIDTH)
   ) decimate (
      .clk_i             (clk_i),
      .clk_2mhz_pos_en_i (clk_2mhz_pos_en_i),
      .ce_i              (ce_i),
      .di_i              (di_i),
      .do_o              (d_2mhz[0])
   );

   generate
      for (i=1; i<M; i=i+1) begin : DECIMATE
         decimate #(
            .M    (M),
            .M_LG (M_WIDTH),
            .DW   (OUTPUT_WIDTH)
         ) decimate (
            .clk_i             (clk_i),
            .clk_2mhz_pos_en_i (clk_2mhz_pos_en_i),
            .ce_i              (ce_i),
            .di_i              (fsr[i-1]),
            .do_o              (d_2mhz[i])
         );
      end
   endgenerate

   // reg signed [INTERNAL_WIDTH-1:0] f0  = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f1  = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f2  = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f3  = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f4  = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f5  = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f6  = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f7  = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f8  = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f9  = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f10 = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f11 = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f12 = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f13 = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f14 = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f15 = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f16 = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f17 = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f18 = {INTERNAL_WIDTH{1'b0}};
   // reg signed [INTERNAL_WIDTH-1:0] f19 = {INTERNAL_WIDTH{1'b0}};

   // always @(posedge clk_120mhz_i) begin
   //    if (ce_i) begin
   //       if (tap_addr == 0) begin
   //          f0  <= tap0  * d_2mhz[0];
   //          f1  <= tap1  * d_2mhz[1];
   //          f2  <= tap2  * d_2mhz[2];
   //          f3  <= tap3  * d_2mhz[3];
   //          f4  <= tap4  * d_2mhz[4];
   //          f5  <= tap5  * d_2mhz[5];
   //          f6  <= tap6  * d_2mhz[6];
   //          f7  <= tap7  * d_2mhz[7];
   //          f8  <= tap8  * d_2mhz[8];
   //          f9  <= tap9  * d_2mhz[9];
   //          f10 <= tap10 * d_2mhz[10];
   //          f11 <= tap11 * d_2mhz[11];
   //          f12 <= tap12 * d_2mhz[12];
   //          f13 <= tap13 * d_2mhz[13];
   //          f14 <= tap14 * d_2mhz[14];
   //          f15 <= tap15 * d_2mhz[15];
   //          f16 <= tap16 * d_2mhz[16];
   //          f17 <= tap17 * d_2mhz[17];
   //          f18 <= tap18 * d_2mhz[18];
   //          f19 <= tap19 * d_2mhz[19];
   //       end else begin
   //          f0  <= f0  + (tap0  * d_2mhz[0]);
   //          f1  <= f1  + (tap1  * d_2mhz[1]);
   //          f2  <= f2  + (tap2  * d_2mhz[2]);
   //          f3  <= f3  + (tap3  * d_2mhz[3]);
   //          f4  <= f4  + (tap4  * d_2mhz[4]);
   //          f5  <= f5  + (tap5  * d_2mhz[5]);
   //          f6  <= f6  + (tap6  * d_2mhz[6]);
   //          f7  <= f7  + (tap7  * d_2mhz[7]);
   //          f8  <= f8  + (tap8  * d_2mhz[8]);
   //          f9  <= f9  + (tap9  * d_2mhz[9]);
   //          f10 <= f10 + (tap10 * d_2mhz[10]);
   //          f11 <= f11 + (tap11 * d_2mhz[11]);
   //          f12 <= f12 + (tap12 * d_2mhz[12]);
   //          f13 <= f13 + (tap13 * d_2mhz[13]);
   //          f14 <= f14 + (tap14 * d_2mhz[14]);
   //          f15 <= f15 + (tap15 * d_2mhz[15]);
   //          f16 <= f16 + (tap16 * d_2mhz[16]);
   //          f17 <= f17 + (tap17 * d_2mhz[17]);
   //          f18 <= f18 + (tap18 * d_2mhz[18]);
   //          f19 <= f19 + (tap19 * d_2mhz[19]);
   //       end
   //    end else begin
   //       f0      <= {INTERNAL_WIDTH{1'b0}};
   //       f1      <= {INTERNAL_WIDTH{1'b0}};
   //       f2      <= {INTERNAL_WIDTH{1'b0}};
   //       f3      <= {INTERNAL_WIDTH{1'b0}};
   //       f4      <= {INTERNAL_WIDTH{1'b0}};
   //       f5      <= {INTERNAL_WIDTH{1'b0}};
   //       f6      <= {INTERNAL_WIDTH{1'b0}};
   //       f7      <= {INTERNAL_WIDTH{1'b0}};
   //       f8      <= {INTERNAL_WIDTH{1'b0}};
   //       f9      <= {INTERNAL_WIDTH{1'b0}};
   //       f10     <= {INTERNAL_WIDTH{1'b0}};
   //       f11     <= {INTERNAL_WIDTH{1'b0}};
   //       f12     <= {INTERNAL_WIDTH{1'b0}};
   //       f13     <= {INTERNAL_WIDTH{1'b0}};
   //       f14     <= {INTERNAL_WIDTH{1'b0}};
   //       f15     <= {INTERNAL_WIDTH{1'b0}};
   //       f16     <= {INTERNAL_WIDTH{1'b0}};
   //       f17     <= {INTERNAL_WIDTH{1'b0}};
   //       f18     <= {INTERNAL_WIDTH{1'b0}};
   //       f19     <= {INTERNAL_WIDTH{1'b0}};
   //    end
   // end

   always @(posedge clk_i) begin
      if (ce_i && clk_2mhz_pos_en_i)
        do_o <= trunc_to_output(f0 + f1 + f2 + f3 + f4 + f5 + f6 + f7 + f8 + f9 + f10
                                + f11 + f12 + f13 + f14 + f15 + f16 + f17 + f18 + f19 >>> TAP_WIDTH+NORM_SHIFT-1);
   end

endmodule // fir_poly
// Local Variables:
// flycheck-verilator-include-path:("/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unimacro/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unisims/")
// End:
