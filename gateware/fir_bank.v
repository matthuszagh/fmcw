`ifndef _FIR_BANK_V_
`define _FIR_BANK_V_
`default_nettype none

module fir_bank #(
   parameter N_TAPS         = 120, /* total number of taps */
   parameter M              = 20,  /* decimation factor */
   parameter BANK_LEN       = 6,   /* N_TAPS/M */
   parameter INPUT_WIDTH    = 12,
   parameter TAP_WIDTH      = 16,
   parameter OUTPUT_WIDTH   = 35   /* same as internal width in fir_poly */
) (
   input wire                            clk,
   input wire                            rst_n,
   input wire signed [INPUT_WIDTH-1:0]   din,
   output wire signed [OUTPUT_WIDTH-1:0] dout,
   input wire [M_LOG2-1:0]               tap_addr,
   input wire signed [TAP_WIDTH-1:0]     tap,
   input wire                            dsp_acc,
   output wire signed [TAP_WIDTH-1:0]    dsp_a,
   output wire signed [INPUT_WIDTH-1:0]  dsp_b,
   input wire signed [OUTPUT_WIDTH-1:0]  dsp_p
);

   localparam M_LOG2        = $clog2(M);
   localparam BANK_LEN_LOG2 = $clog2(BANK_LEN);

   reg signed [INPUT_WIDTH-1:0]         shift_reg [0:BANK_LEN-1];

   integer i;
   always @(posedge clk) begin
      if (!rst_n) begin
         for (i=0; i<BANK_LEN; i=i+1)
           shift_reg[i] <= 0;
      end else begin
         if (tap_addr == {M_LOG2{1'b0}}) begin
            shift_reg[0] <= din;
            for (i=1; i<BANK_LEN; i=i+1)
              shift_reg[i] <= shift_reg[i-1];
         end
      end
   end

   reg signed [INPUT_WIDTH-1:0]       dsp_din;

   always @(*) begin
      case (dsp_acc)
      0: dsp_din       = din;
      default: dsp_din = shift_reg[tap_addr[BANK_LEN_LOG2-1:0]];
      endcase
   end

   // TODO use BANK_LEN parameter for 5'd6 but while ensuring module
   // generality and only using correct number of bits.
   assign dsp_a = tap_addr < 5'd6 ? tap : {TAP_WIDTH{1'b0}};
   assign dsp_b = tap_addr < 5'd6 ? dsp_din : {INPUT_WIDTH{1'b0}};

   reg signed [OUTPUT_WIDTH-1:0] p_reg;

   always @(posedge clk) begin
      if (tap_addr == 5'd8) begin
         p_reg <= dsp_p[OUTPUT_WIDTH-1:0];
      end
   end

   assign dout = p_reg;

endmodule
`endif
