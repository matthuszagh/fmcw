`default_nettype none

module fft_r22sdf_bfi #(
   parameter DATA_WIDTH    = 25,
   parameter SHIFT_REG_LEN = 512
) (
   input wire                         clk_i,
   input wire                         rst_n,
   input wire                         sel_i,
   input wire signed [DATA_WIDTH-1:0] x_re_i,
   input wire signed [DATA_WIDTH-1:0] x_im_i,
   output reg signed [DATA_WIDTH-1:0] z_re_o,
   output reg signed [DATA_WIDTH-1:0] z_im_o
);

   wire signed [DATA_WIDTH-1:0]       sr_re;
   wire signed [DATA_WIDTH-1:0]       sr_im;

   generate
      if (SHIFT_REG_LEN > 32) begin
         shift_reg #(
            .DATA_WIDTH (DATA_WIDTH),
            .LEN        (SHIFT_REG_LEN)
         ) shift_reg_re (
            .clk    (clk_i),
            .rst_n  (rst_n),
            .di     (zsr_re),
            .data_o (sr_re)
         );

         shift_reg #(
            .DATA_WIDTH (DATA_WIDTH),
            .LEN        (SHIFT_REG_LEN)
         ) shift_reg_im (
            .clk    (clk_i),
            .rst_n  (rst_n),
            .di     (zsr_im),
            .data_o (sr_im)
         );
      end else begin
         reg signed [DATA_WIDTH-1:0]        sr_re_reg [0:SHIFT_REG_LEN-1];
         reg signed [DATA_WIDTH-1:0]        sr_im_reg [0:SHIFT_REG_LEN-1];
         integer                    i;
         always @(posedge clk_i) begin
            if (!rst_n) begin
               for (i=0; i<SHIFT_REG_LEN; i=i+1) begin
                  sr_re_reg[i] = {DATA_WIDTH{1'b0}};
                  sr_im_reg[i] = {DATA_WIDTH{1'b0}};
               end
            end else begin
               sr_re_reg[0] <= zsr_re;
               sr_im_reg[0] <= zsr_im;
               for (i=1; i<SHIFT_REG_LEN; i=i+1) begin
                  sr_re_reg[i] <= sr_re_reg[i-1];
                  sr_im_reg[i] <= sr_im_reg[i-1];
               end
            end
         end
         assign sr_re = sr_re_reg[SHIFT_REG_LEN-1];
         assign sr_im = sr_im_reg[SHIFT_REG_LEN-1];
      end
   endgenerate

   wire signed [DATA_WIDTH-1:0]       xsr_re;
   wire signed [DATA_WIDTH-1:0]       xsr_im;
   reg signed [DATA_WIDTH-1:0]        zsr_re;
   reg signed [DATA_WIDTH-1:0]        zsr_im;

   assign xsr_re = sr_re;
   assign xsr_im = sr_im;

   always @(*) begin
      if (sel_i) begin
         z_re_o = x_re_i + xsr_re;
         z_im_o = x_im_i + xsr_im;
         zsr_re = xsr_re - x_re_i;
         zsr_im = xsr_im - x_im_i;
      end else begin
         z_re_o = xsr_re;
         z_im_o = xsr_im;
         zsr_re = x_re_i;
         zsr_im = x_im_i;
      end
   end

endmodule
// Local Variables:
// flycheck-verilator-include-path:("/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unimacro/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unisims/"
//                                  "/home/matt/src/libdigital/libdigital/hdl/memory/shift_reg/")
// End:
