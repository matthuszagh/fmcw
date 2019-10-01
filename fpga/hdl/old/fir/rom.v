`default_nettype none

// `include "BRAM_TDP_MACRO.v"
// `include "RAMB18E1.v"
// `include "glbl.v"

module rom #(
   parameter ROMFILE       = "",
   parameter ADDRESS_WIDTH = 7,
   parameter DATA_WIDTH    = 16,
   parameter ROM_SIZE      = 128
) (
   input wire                          clk,
   input wire                          en1,
   input wire                          en2,
   input wire [ADDRESS_WIDTH-1:0]      addr1,
   input wire [ADDRESS_WIDTH-1:0]      addr2,
   output wire signed [DATA_WIDTH-1:0] do1,
   output wire signed [DATA_WIDTH-1:0] do2
);

   BRAM_TDP_MACRO #(
      .BRAM_SIZE     ("18Kb"),
      .DEVICE        ("7SERIES"),
      .DOA_REG       (0),
      .DOB_REG       (0),
      .WRITE_WIDTH_A (ADDRESS_WIDTH),
      .WRITE_WIDTH_B (ADDRESS_WIDTH),
      .READ_WIDTH_A  (ADDRESS_WIDTH),
      .READ_WIDTH_B  (ADDRESS_WIDTH),
      .INIT_FILE     (ROMFILE),
      .WRITE_MODE_A  ("NO_CHANGE"),
      .WRITE_MODE_B  ("NO_CHANGE")
   ) BRAM (
      .DOA   (do1),
      .DOB   (do2),
      .ADDRA (addr1),
      .ADDRB (addr2),
      .CLKA  (clk),
      .CLKB  (clk),
      .ENA   (en1),
      .ENB   (en2),
      .RSTA  (1'b0),
      .RSTB  (1'b0),
      .WEA   (1'b0),
      .WEB   (1'b0)
   );

endmodule // rom
// Local Variables:
// flycheck-verilator-include-path:("/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unimacro/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unisims/")
// End:
