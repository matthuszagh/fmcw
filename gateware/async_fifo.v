`ifndef _ASYNC_FIFO_V_
`define _ASYNC_FIFO_V_

`default_nettype none
`timescale 1ns/1ps

`include "ram.v"

/** async_fifo.v
 *
 * Asynchronous FIFO
 *
 * This must be initialized in its reset state. The reset signal
 * must be asserted for a minimum of one full period of the slowest
 * clock.
 */
module async_fifo #(
   parameter WIDTH = 64,
   parameter SIZE  = 1024
) (
   input wire              rst_n,
   output reg              full,
   output wire             empty,
   input wire              rdclk,
   input wire              rden,
   output wire [WIDTH-1:0] rddata,
   input wire              wrclk,
   input wire              wren,
   input wire [WIDTH-1:0]  wrdata
);

   reg [$clog2(SIZE)-1:0]  rdaddr;
   reg [$clog2(SIZE)-1:0]  wraddr;

   assign empty = (rdaddr == wraddr);

   always @(posedge rdclk) begin
      if (!rst_n) begin
         rdaddr <= {$clog2(SIZE){1'b0}};
      end else if (rden && rdaddr != wraddr) begin
         rdaddr <= rdaddr + 1'b1;
      end
   end

   always @(posedge wrclk) begin
      if (!rst_n) begin
         wraddr <= {$clog2(SIZE){1'b0}};
         full <= 1'b0;
      end else begin
         if (rdaddr - wraddr == {{$clog2(SIZE)-1{1'b0}}, 1'b1}) begin
            full <= 1'b1;
         end else begin
            full <= 1'b0;
            if (wren)
              wraddr <= wraddr + 1'b1;
         end
      end
   end

   // We guard reads when the FIFO is empty and guard writes when it
   // is full. This is critical to allowing reads to occur when
   // simultaneously reading and writing from/to the FIFO. The reason
   // for this is that the underlying RAM module prevents simultaneous
   // access to the same data.
   ram #(
      .WIDTH (WIDTH ),
      .SIZE  (SIZE  )
   ) ram (
      .rdclk  (rdclk          ),
      .rden   (rden && !empty ),
      .rdaddr (rdaddr         ),
      .rddata (rddata         ),
      .wrclk  (wrclk          ),
      .wren   (wren && !full  ),
      .wraddr (wraddr         ),
      .wrdata (wrdata         )
   );

`ifdef FORMAL
   // Generate read and write clocks. Assume the write clock has 1.5x
   // the period of the read clock.
   (* gclk *) reg formal_timestep;
   integer formal_ctr = 0;
   reg rdclk_ctr = 0;
   reg [1:0] wrclk_ctr = 0;
   reg [1:0] rst_ctr = 0;
   always @(posedge formal_timestep) begin
      formal_ctr <= formal_ctr + 1;

      if ($initstate) begin
         assume (rdclk == 0);
         assume (wrclk == 0);
      end else begin
         rdclk_ctr <= ~rdclk_ctr;
         if (rdclk_ctr)
           assume ($changed(rdclk));
         else
           assume ($stable(rdclk));

         if (wrclk_ctr == 2) begin
            wrclk_ctr <= 0;
            assume ($changed(wrclk));
         end else begin
            wrclk_ctr <= wrclk_ctr + 1;
            assume ($stable(wrclk));
         end
      end

      // Ensure reset asserted long enough to be registered by all
      // clocks.
      if (formal_ctr < 3) begin
         assume (rst_n == 0);
      end else begin
         if ($fell(rst_n) || (!$past(rst_n) && $past(rst_n, 2)))
           assume ($stable(rst_n));
      end
   end

   reg rdinit = 1;
   reg rd_past_valid = 0;
   always @(posedge rdclk) begin
      rd_past_valid <= 1;

      if (rd_past_valid) begin
         // Ensure the read address never overtakes the write address.
         // It is possible for this to occur during a reset. However,
         // by the end of the reset both addresses will be zeroed, so
         // this isn't an issue and we ignore it.
         if (rst_n) begin
            if ($past(rdaddr) == $past(wraddr)) begin
               if ($past(rdaddr) == SIZE-1) begin
                  if (wraddr != 0) begin
                     assert (rdaddr != 0);
                  end
               end else begin
                  assert (!(rdaddr > wraddr));
               end
            end
         end
      end
   end

   reg wrinit = 1;
   reg wr_past_valid = 0;
   always @(posedge wrclk) begin
      wr_past_valid <= 1;

      if (wr_past_valid) begin
         if (!$past(rst_n))
           assert (!full);
      end
   end
`endif

`ifdef COCOTB_SIM
   // integer i;
   initial begin
      $dumpfile ("cocotb/build/async_fifo.vcd");
      $dumpvars (0, async_fifo);
      // for (i=0; i<100; i=i+1)
      //   $dumpvars (0, ram.mem[i]);
      #1;
   end
`endif

endmodule
`endif
