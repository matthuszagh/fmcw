`ifndef _SHIFT_REG_V_
`define _SHIFT_REG_V_

`default_nettype none

`include "ram.v"

// Note that this module only supports reading from the end of the
// shift register due to the fact that it's based on dual-port RAM. If
// you need to read from more than just the last register, implement
// the shift register with flip-flops.

module shift_reg #(
   parameter DATA_WIDTH = 25,
   parameter LEN        = 512
) (
   input wire                   clk,
   input wire                   rst_n,
   input wire                   ce,
   input wire [DATA_WIDTH-1:0]  di,
   output wire [DATA_WIDTH-1:0] data_o
);

   localparam [$clog2(LEN-1)-1:0] LEN_CMP = LEN-1;

   reg [$clog2(LEN)-1:0]           addr;
   reg [$clog2(LEN)-1:0]           rdaddr;
   always @(posedge clk) begin
      if (!rst_n) begin
         addr <= {$clog2(LEN){1'b0}};
         rdaddr <= {{$clog2(LEN)-1{1'b0}}, 1'b1};
      end else if (ce) begin
         if (addr == LEN_CMP) begin
            addr <= {$clog2(LEN){1'b0}};
         end else begin
            addr <= addr + 1'b1;
         end

         if (rdaddr == LEN_CMP) begin
            rdaddr <= {$clog2(LEN){1'b0}};
         end else begin
            rdaddr <= rdaddr + 1'b1;
         end
      end
   end

   // It's possible to keep read and write enables asserted
   // simultaneously because the read and write addresses will always
   // be different.
   ram #(
      .WIDTH (DATA_WIDTH ),
      .SIZE  (LEN        )
   ) ram (
      .rdclk  (clk       ),
      .rden   (ce        ),
      .rdaddr (rdaddr    ),
      .rddata (data_o    ),
      .wrclk  (clk       ),
      .wren   (ce        ),
      .wraddr (addr      ),
      .wrdata (di        )
   );

`ifdef COCOTB_SIM
   initial begin
      $dumpfile ("cocotb/build/shift_reg.vcd");
      $dumpvars (0, shift_reg);
      #1;
   end
`endif

endmodule

// TODO remove
`ifdef SHIFT_REG_SIMULATE
`include "BRAM_SDP_MACRO.v"
`include "RAMB18E1.v"
`include "glbl.v"
`timescale 1ns/1ps
module shift_reg_tb;

   localparam DATA_WIDTH = 25;
   localparam LEN = 10;

   reg clk = 0;
   reg rst_n = 0;
   always #1 clk = !clk;
   reg [DATA_WIDTH-1:0] sample = 0;
   wire [DATA_WIDTH-1:0] data;

   always @(posedge clk) begin
      if (!dut.BRAM_SDP.bram18_sdp_bl_3.bram18_sdp_bl_3.GSR)
        rst_n <= 1;

      if (!rst_n)
        sample <= 0;
      else
        sample <= sample + 1;
   end

   initial begin
      $dumpfile("tb/shift_reg_tb.vcd");
      $dumpvars(0, shift_reg_tb);

      #10000 $finish;
   end

   shift_reg #(
      .DATA_WIDTH (DATA_WIDTH),
      .LEN        (LEN)
   ) dut (
      .clk      (clk),
      .rst_n    (rst_n),
      .di       (sample),
      .data_o   (data)
   );

endmodule
`endif
`endif
