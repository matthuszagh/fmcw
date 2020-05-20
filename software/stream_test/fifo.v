`ifndef _FIFO_V_
`define _FIFO_V_

`default_nettype none
`timescale 1ns/1ps

`include "ram.v"
`include "ff_sync.v"
`include "gray_ctr.v"

// The design for this FIFO is based on the design in Clifford
// Cummings paper "Simulation and Synthesis Techniques for
// Asynchronous FIFO Design".

module fifo #(
   parameter WIDTH = 64,
   parameter DEPTH = 1024
) (
   // write clock domain
   input wire              wclk,
   input wire              rst_n,
   input wire              wen,
   output reg              full,
   output wire             almost_full,
   input wire [WIDTH-1:0]  wdata,
   // read clock domain
   input wire              rclk,
   input wire              ren,
   output reg              empty,
   output wire             almost_empty,
   output wire [WIDTH-1:0] rdata
);

   localparam ADDR_WIDTH = $clog2(DEPTH);

   wire                    full_next;
   wire                    empty_next;

   wire [ADDR_WIDTH-1:0]   waddr;
   wire [ADDR_WIDTH-1:0]   raddr;

   wire [ADDR_WIDTH:0]     wgray;
   wire [ADDR_WIDTH:0]     wgray_next;

   wire [ADDR_WIDTH:0]     rgray;
   wire [ADDR_WIDTH:0]     rgray_next;

   wire [ADDR_WIDTH:0]     wgray_rdomain;
   wire [ADDR_WIDTH:0]     rgray_wdomain;

   reg                     rrst_n;
   reg                     wrst_n;
   reg [1:0]               rrst_sync;
   reg [1:0]               wrst_sync;

   always @(posedge wclk or negedge rst_n) begin
      if (!rst_n) begin
         {wrst_n, wrst_sync} <= 3'b000;
      end else begin
         {wrst_n, wrst_sync} <= {wrst_sync, 1'b1};
      end
   end

   always @(posedge rclk or negedge rst_n) begin
      if (!rst_n) begin
         {rrst_n, rrst_sync} <= 3'b000;
      end else begin
         {rrst_n, rrst_sync} <= {rrst_sync, 1'b1};
      end
   end

   gray_ctr #(
      .WIDTH (ADDR_WIDTH+1)
   ) wgray_ctr (
      .inc       (wen && !full ),
      .clk       (wclk         ),
      .rst_n     (wrst_n       ),
      .gray      (wgray        ),
      .gray_next (wgray_next   ),
      .bin       (waddr        )
   );

   gray_ctr #(
      .WIDTH (ADDR_WIDTH+1)
   ) rgray_ctr (
      .inc       (ren && !empty ),
      .rst_n     (rrst_n        ),
      .clk       (rclk          ),
      .gray      (rgray         ),
      .gray_next (rgray_next    ),
      .bin       (raddr         )
   );

   ff_sync #(
      .WIDTH  (ADDR_WIDTH+1 ),
      .STAGES (2            )
   ) wptr_sync (
      .dest_clk (rclk          ),
      .d        (wgray         ),
      .q        (wgray_rdomain )
   );
   assign empty_next = (rgray_next == wgray_rdomain);
   // TODO this should be registered
   assign almost_empty = empty_next;
   always @(posedge rclk) begin
      if (!rrst_n) begin
         empty <= 1'b1;
      end else begin
         empty <= empty_next;
      end
      // next_empty <= (raddr + 1'b1) == ;
   end

   ff_sync #(
      .WIDTH  (ADDR_WIDTH+1 ),
      .STAGES (2            )
   ) rptr_sync (
      .dest_clk (wclk          ),
      .d        (rgray         ),
      .q        (rgray_wdomain )
   );
   assign full_next = (wgray_next == {~rgray_wdomain[ADDR_WIDTH:ADDR_WIDTH-1], rgray_wdomain[ADDR_WIDTH-2:0]});
   assign almost_full = full_next;
   always @(posedge wclk) begin
      if (!wrst_n) begin
         full <= 1'b1;
      end else begin
         full <= full_next;
      end
   end

   ram #(
      .WIDTH (WIDTH ),
      .SIZE  (DEPTH )
   ) ram (
      .rdclk  (rclk          ),
      .rden   (ren && !empty ),
      .rdaddr (raddr         ),
      .rddata (rdata         ),
      .wrclk  (wclk          ),
      .wren   (wen && !full  ),
      .wraddr (waddr         ),
      .wrdata (wdata         )
   );

endmodule

`ifdef SIMULATE
module fifo_tb;

   reg clk40 = 1'b0;
   reg clk80 = 1'b0;
   reg clk60 = 1'b0;
   reg  rst_n = 1'b0;

   initial begin
      $dumpfile("tb/fifo_tb.vcd");
      $dumpvars(0, fifo_tb);

      #50 rst_n = 1'b1;

      #100000 $finish;
   end

   always #12.5 clk40 = !clk40;
   always #6.25 clk80 = !clk80;
   always #16.67 clk60 = !clk60;

   reg [7:0] ctr;
   reg       wen;
   wire full;
   wire empty;
   always @(posedge clk80) begin
      if (!dut.wrst_n) begin
         ctr <= 8'd0;
         wen <= 1'b0;
      end else begin
         if (!full) begin
            wen <= 1'b1;
            ctr <= ctr + 1'b1;
         end else begin
            wen <= 1'b0;
         end
      end
   end

   reg ren;
   always @(posedge clk60) begin
      if (!rst_n) begin
         ren <= 1'b0;
      end else begin
         if (!empty) begin
            ren <= 1'b1;
         end else begin
            ren <= 1'b0;
         end
      end
   end

   wire [7:0] out_ctr;
   fifo # (
      .WIDTH (8    ),
      .DEPTH (1024 )
   ) dut (
      .wclk  (clk80   ),
      .rst_n (rst_n   ),
      .wen   (wen     ),
      .full  (full    ),
      .wdata (ctr     ),
      .rclk  (clk60   ),
      .ren   (ren     ),
      .empty (empty   ),
      .rdata (out_ctr )
   );

endmodule
`endif
`endif
