`ifndef _FIR_BANK_V_
`define _FIR_BANK_V_

`default_nettype none
`timescale 1ns/1ps

module fir_bank #(
   parameter N_TAPS       = 120, /* total number of taps */
   parameter M            = 20,  /* decimation factor */
   parameter BANK_LEN     = 6,   /* N_TAPS/M */
   parameter INPUT_WIDTH  = 12,
   parameter TAP_WIDTH    = 16,
   parameter OUTPUT_WIDTH = 35   /* same as internal width in fir */
) (
   input wire                            clk,
   input wire signed [INPUT_WIDTH-1:0]   din,
   output wire signed [OUTPUT_WIDTH-1:0] dout,
   input wire [$clog2(M)-1:0]            tap_addr,
   input wire signed [TAP_WIDTH-1:0]     tap,
   input wire                            dsp_acc,
   output wire signed [TAP_WIDTH-1:0]    dsp_a,
   output wire signed [INPUT_WIDTH-1:0]  dsp_b,
   input wire signed [OUTPUT_WIDTH-1:0]  dsp_p
);

   reg signed [INPUT_WIDTH-1:0] shift_reg [0:BANK_LEN-1];
   integer i;
   initial for (i=0; i<BANK_LEN; i=i+1) shift_reg[i] = {INPUT_WIDTH{1'b0}};

   always @(posedge clk) begin
      if (tap_addr == {$clog2(M){1'b0}}) begin
         shift_reg[0] <= din;
         for (i=1; i<BANK_LEN; i=i+1) shift_reg[i] <= shift_reg[i-1];
      end
   end

   reg signed [INPUT_WIDTH-1:0] dsp_din = {INPUT_WIDTH{1'b0}};

   always @(*) begin
      case (dsp_acc)
      1'b0: dsp_din = din;
      1'b1: dsp_din = shift_reg[tap_addr[$clog2(BANK_LEN)-1:0]];
      endcase
   end

   // TODO use BANK_LEN parameter for 5'd6 but while ensuring module
   // generality and only using correct number of bits.
   assign dsp_a = tap_addr < 5'd6 ? tap : {TAP_WIDTH{1'b0}};
   assign dsp_b = tap_addr < 5'd6 ? dsp_din : {INPUT_WIDTH{1'b0}};

   reg signed [OUTPUT_WIDTH-1:0] p_reg = {OUTPUT_WIDTH{1'b0}};

   always @(posedge clk) begin
      if (tap_addr == 5'd8)  p_reg <= dsp_p[OUTPUT_WIDTH-1:0];
   end

   assign dout = p_reg;

endmodule
`endif
