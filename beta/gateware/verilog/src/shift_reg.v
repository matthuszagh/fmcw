`ifndef _SHIFT_REG_V_
`define _SHIFT_REG_V_

`default_nettype none
`timescale 1ns/1ps

`include "ram.v"

// Note that this module only supports reading from the end of the
// shift register due to the fact that it's designed to support
// dual-port RAM. If you need to read from more than just the last
// register, implement the shift register with flip-flops.

module shift_reg #(
   parameter WIDTH = 25,
   parameter LEN   = 512
) (
   input wire              clk,
   input wire [WIDTH-1:0]  di,
   output wire [WIDTH-1:0] data_o
);

   /* verilator lint_off WIDTH */
   localparam [$clog2(LEN)-1:0] LEN_MAX = LEN-1;
   /* verilator lint_on WIDTH */

   reg [$clog2(LEN)-1:0]        addr   = {$clog2(LEN){1'b0}};
   reg [$clog2(LEN)-1:0]        rdaddr = {{$clog2(LEN)-1{1'b0}}, 1'b1};
   always @(posedge clk) begin
      if (addr == LEN_MAX) begin
         addr <= {$clog2(LEN){1'b0}};
      end else begin
         addr <= addr + 1'b1;
      end

      if (rdaddr == LEN_MAX) begin
         rdaddr <= {$clog2(LEN){1'b0}};
      end else begin
         rdaddr <= rdaddr + 1'b1;
      end
   end

   // It's possible to keep read and write enables asserted
   // simultaneously because the read and write addresses will always
   // be different.
   ram #(
      .WIDTH (WIDTH ),
      .SIZE  (LEN   )
   ) ram (
      .rdclk  (clk       ),
      .rden   (1'b1      ),
      .rdaddr (rdaddr    ),
      .rddata (data_o    ),
      .wrclk  (clk       ),
      .wren   (1'b1      ),
      .wraddr (addr      ),
      .wrdata (di        )
   );

`ifdef COCOTB_SIM
   `ifdef SHIFT_REG
   initial begin
      $dumpfile ("cocotb/build/shift_reg.vcd");
      $dumpvars (0, shift_reg);
      #1;
   end
   `endif
`endif

endmodule
`endif
