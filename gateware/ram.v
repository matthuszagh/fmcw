`ifndef _RAM_V_
`define _RAM_V_

`default_nettype none

// General-purpose RAM module with one read and one write port and
// allows (but does not require) independent read and write clocks. It
// is designed to infer block RAM on devices that support it.

// This module guards against read/write collisions by prioritizing
// reads. In other words, if you attempt to read and write to the same
// address in the same clock period, the write will be ignored. Make
// sure that you only assert `rden' and `wren' when necessary.

module ram #(
   parameter INITFILE = "",
   parameter WIDTH    = 64,
   parameter SIZE     = 512
) (
   input wire             rdclk,
   input wire             rden,
   input wire [ABITS-1:0] rdaddr,
   output reg [WIDTH-1:0] rddata,
   input wire             wrclk,
   input wire             wren,
   input wire [ABITS-1:0] wraddr,
   input wire [WIDTH-1:0] wrdata
);

   localparam ABITS = $clog2(SIZE);

   reg [WIDTH-1:0]        mem [0:SIZE-1];

   integer                i;
   generate
      /* verilator lint_off WIDTH */
      if (INITFILE == "") begin
         initial begin
            for (i=0; i<SIZE; i=i+1)
              mem[i] = {WIDTH{1'b0}};
         end
      end else begin
         initial begin
            $readmemh(INITFILE, mem);
         end
      end
      /* verilator lint_on WIDTH */
   endgenerate

   wire                   conflict = (rden && wren) ? (rdaddr == wraddr) : 1'b0;

   always @(posedge rdclk) begin
      if (rden) begin
         rddata <= mem[rdaddr];
      end
   end

   // Prioritize reads when read/write conflicts occur.
   always @(posedge wrclk) begin
      if (wren && !conflict) begin
         mem[wraddr] <= wrdata;
      end
   end

`ifdef FORMAL
   // TODO
`endif

endmodule
`endif
