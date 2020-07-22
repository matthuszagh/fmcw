`ifndef _SYNC_FIFO_V_
`define _SYNC_FIFO_V_

`default_nettype none
`timescale 1ns/1ps

`include "ram.v"

/** sync_fifo.v
 *
 * Synchronous FIFO.
 */

module sync_fifo #(
   parameter WIDTH = 64,
   parameter DEPTH = 1024
) (
   input wire              clk,
   input wire              srst_n,
   input wire              wen,
   input wire [WIDTH-1:0]  wdata,
   output reg              full = 1'b0,
   input wire              ren,
   output wire [WIDTH-1:0] rdata,
   output reg              empty = 1'b1
);

   reg [$clog2(DEPTH)-1:0] raddr = {$clog2(DEPTH){1'b0}};
   reg [$clog2(DEPTH)-1:0] waddr = {$clog2(DEPTH){1'b0}};

   always @(posedge clk) begin
      if (~srst_n) begin
         raddr <= {$clog2(DEPTH){1'b0}};
         empty <= 1'b1;
      end else begin
         if (ren & ~empty) begin
            raddr <= raddr + 1'b1;
            if (raddr + 1'b1 == waddr) empty <= 1'b1;
            else                       empty <= 1'b0;
         end
         else if (raddr != waddr) empty <= 1'b0;
      end
   end

   always @(posedge clk) begin
      if (~srst_n) begin
         waddr <= {$clog2(DEPTH){1'b0}};
         full  <= 1'b0;
      end else begin
         if (wen & ~full) begin
            waddr <= waddr + 1'b1;
            if (waddr + 1'b1 == raddr) full <= 1'b1;
            else                       full <= 1'b0;
         end
         else if (waddr != raddr) full <= 1'b0;
      end
   end

   ram #(
      .WIDTH (WIDTH ),
      .SIZE  (DEPTH )
   ) ram (
      .rdclk  (clk         ),
      .rden   (ren         ),
      .rdaddr (raddr       ),
      .rddata (rdata       ),
      .wrclk  (clk         ),
      .wren   (wen & ~full ),
      .wraddr (waddr       ),
      .wrdata (wdata       )
   );

`ifdef FORMAL
   // TODO
`endif

endmodule

`ifdef SYNC_FIFO_ICARUS
`timescale 1ns/1ps
module sync_fifo_tb;

   localparam DATA_WIDTH = 64;

   reg clk = 0;

   reg ren = 0;
   reg wen = 1;
   reg srst_n = 0;

   reg [DATA_WIDTH-1:0] data = 0;

   always #5 clk = !clk;

   always #500 ren = ~ren;

   initial begin
      $dumpfile("icarus/sync_fifo_tb.vcd");
      $dumpvars(0, sync_fifo_tb);

      #100 srst_n = 1;
      #10000 wen = 0;
      #20000 $finish;
   end

   always @(posedge clk) begin
      if (!srst_n) begin
         data <= 0;
      end else if (wen) begin
         data <= data + 1'b1;
      end
   end

   wire full;
   wire empty;
   wire [DATA_WIDTH-1:0] rd_data;

   sync_fifo #(
      .WIDTH (DATA_WIDTH ),
      .DEPTH (512        )
   ) dut (
      .clk    (clk     ),
      .srst_n (srst_n  ),
      .ren    (ren     ),
      .wen    (wen     ),
      .full   (full    ),
      .empty  (empty   ),
      .rdata  (rd_data ),
      .wdata  (data    )
   );

endmodule
`endif
`endif
