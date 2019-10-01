`default_nettype none

`include "dsp.v"

module bank #(
   parameter N_TAPS         = 120, /* total number of taps */
   parameter M              = 20,  /* decimation factor */
   parameter BANK_LEN       = 6,   /* N_TAPS/M */
   parameter INPUT_WIDTH    = 12,
   parameter TAP_WIDTH      = 16,
   parameter OUTPUT_WIDTH   = 35,  /* same as internal width in fir_poly */
   parameter DSP_A_WIDTH    = 25,
   parameter DSP_B_WIDTH    = 18,
   parameter DSP_P_WIDTH    = 48
) (
   input wire                            clk,
   input wire                            rst_n,
   input wire                            clk_2mhz_pos_en,
   input wire signed [INPUT_WIDTH-1:0]   din,
   output wire signed [OUTPUT_WIDTH-1:0] dout,
   input wire [M_LOG2-1:0]               tap_addr,
   input wire signed [TAP_WIDTH-1:0]     tap,
   input wire                            dsp_acc,
   output wire signed [DSP_A_WIDTH-1:0]  dsp_a,
   output wire signed [DSP_B_WIDTH-1:0]  dsp_b,
   input wire signed [DSP_P_WIDTH-1:0]   dsp_p
);

   localparam M_LOG2        = $clog2(M);
   localparam BANK_LEN_LOG2 = $clog2(BANK_LEN);

   function [DSP_A_WIDTH-1:0] sign_extend_a(input [TAP_WIDTH-1:0] expr);
      sign_extend_a = (expr[TAP_WIDTH-1] == 1'b1) ? {{DSP_A_WIDTH-TAP_WIDTH{1'b1}}, expr}
                      : {{DSP_A_WIDTH-TAP_WIDTH{1'b0}}, expr};
   endfunction
   function [DSP_B_WIDTH-1:0] sign_extend_b(input [INPUT_WIDTH-1:0] expr);
      sign_extend_b = (expr[INPUT_WIDTH-1] == 1'b1) ? {{DSP_B_WIDTH-INPUT_WIDTH{1'b1}}, expr}
                      : {{DSP_B_WIDTH-INPUT_WIDTH{1'b0}}, expr};
   endfunction

   reg signed [INPUT_WIDTH-1:0]         shift_reg [0:BANK_LEN-2];

   integer i;
   always @(posedge clk) begin
      if (!rst_n) begin
         for (i=0; i<BANK_LEN-1; i=i+1)
           shift_reg[i] <= 0;
      end else begin
         if (tap_addr == {M_LOG2{1'b0}}) begin
            shift_reg[0] <= din;
            for (i=1; i<BANK_LEN-1; i=i+1)
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

   assign dsp_a = sign_extend_a(tap_addr < 5'd5 ? tap : {DSP_A_WIDTH{1'b0}});
   assign dsp_b = sign_extend_b(tap_addr < 5'd5 ? dsp_din : {DSP_B_WIDTH{1'b0}});

   reg signed [OUTPUT_WIDTH-1:0] p_reg;

   always @(posedge clk) begin
      if (tap_addr == 5'd8) begin
         p_reg <= dsp_p[OUTPUT_WIDTH-1:0];
      end
   end

   assign dout = p_reg;

endmodule
// Local Variables:
// flycheck-verilator-include-path:("/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unimacro/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unisims/")
// End:
