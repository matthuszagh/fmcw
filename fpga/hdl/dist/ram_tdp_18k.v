`default_nettype none

module ram_tdp_18k #(
   parameter ROMFILE       = "",
   parameter ADDRESS_WIDTH = 7,
   parameter DATA_WIDTH    = 16,
   parameter ROM_SIZE      = 128
) (
   input wire                          clk1,
   input wire                          clk2,
   input wire                          en1,
   input wire                          en2,
   input wire                          we1,
   input wire                          we2,
   input wire [ADDRESS_WIDTH-1:0]      addr1,
   input wire [ADDRESS_WIDTH-1:0]      addr2,
   input wire signed [DATA_WIDTH-1:0]  di1,
   input wire signed [DATA_WIDTH-1:0]  di2,
   output wire signed [DATA_WIDTH-1:0] do1,
   output wire signed [DATA_WIDTH-1:0] do2
);

   // TODO the address and write enable widths are incorrect. See the
   // Xilinx table for how to fix.
   BRAM_TDP_MACRO #(
      .BRAM_SIZE     ("18Kb"),
      .DEVICE        ("7SERIES"),
      .DOA_REG       (0),
      .DOB_REG       (0),
      .WRITE_WIDTH_A (DATA_WIDTH),
      .WRITE_WIDTH_B (DATA_WIDTH),
      .READ_WIDTH_A  (DATA_WIDTH),
      .READ_WIDTH_B  (DATA_WIDTH),
      .INIT_FILE     (ROMFILE),
      .WRITE_MODE_A  ("NO_CHANGE"),
      .WRITE_MODE_B  ("NO_CHANGE")
   ) BRAM (
      .DOA   (do1),
      .DOB   (do2),
      .DIA   (di1),
      .DIB   (di2),
      .ADDRA (addr1),
      .ADDRB (addr2),
      .CLKA  (clk1),
      .CLKB  (clk2),
      .ENA   (en1),
      .ENB   (en2),
      .RSTA  (1'b0),
      .RSTB  (1'b0),
      .WEA   ({we1, we1}),
      .WEB   ({we2, we2})
   );

endmodule

`ifdef RAM_TDP_18K_SIMULATE
`include "BRAM_TDP_MACRO.v"
`include "RAMB18E1.v"
`include "glbl.v"
`timescale 1ns/1ps
module ram_tdp_18k_tb;

   localparam RAM_LEN       = 1024;
   localparam ADDRESS_WIDTH = $clog2(RAM_LEN);
   localparam DATA_WIDTH    = 16;

   reg clk1                      = 1'b0;
   reg clk2                      = 1'b0;

   always #5 clk1                = !clk1;
   always #1 clk2                = !clk2;

   initial begin
      $dumpfile("tb/ram_tdp_18k_tb.vcd");
      $dumpvars(0, ram_tdp_18k_tb);

      #100 rst_n = 1'b1;

      #100000 $finish;
   end

   reg en1                       = 1'b1;
   reg en2                       = 1'b1;
   reg we1                       = 1'b1;
   reg we2                       = 1'b0;
   reg [ADDRESS_WIDTH-1:0] addr1 = {ADDRESS_WIDTH{1'b0}};
   reg [ADDRESS_WIDTH-1:0] addr2 = {ADDRESS_WIDTH{1'b0}};
   wire signed [DATA_WIDTH-1:0] do1;
   wire signed [DATA_WIDTH-1:0] do2;

   reg signed [DATA_WIDTH-1:0]  di = 0;

   reg                          rst_n = 1'b0;

   always @(posedge clk1) begin
      if (!rst_n) begin
         addr1 <= 0;
         di    <= 0;
      end else begin
         addr1 <= addr1 + 1'b1;
         di    <= di + 1'b1;
      end
   end

   // reg state = 1'b0; // 0 is write state, 1 is read
   reg start_read = 1'b0;

   always @(posedge clk2) begin
      if (!rst_n) begin
         start_read <= 0;
         addr2      <= 0;
      end else begin
         if (addr2 == RAM_LEN-1) begin
            start_read <= 1'b0;
            addr2      <= 0;
         end else if (addr1 == RAM_LEN-1 || start_read) begin
            addr2 <= addr2 + 1'b1;
            start_read <= 1'b1;
         end
      end
   end

   ram_tdp_18k #(
      .ADDRESS_WIDTH (ADDRESS_WIDTH),
      .DATA_WIDTH    (DATA_WIDTH)
   ) ram (
      .clk1  (clk1),
      .clk2  (clk2),
      .en1   (en1),
      .en2   (en2),
      .we1   (we1),
      .we2   (we2),
      .addr1 (addr1),
      .addr2 (addr2),
      .do1   (do1),
      .do2   (do2),
      .di1   (di)
   );

endmodule
`endif
// Local Variables:
// flycheck-verilator-include-path:("/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unimacro/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unisims/")
// End:
