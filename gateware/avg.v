`ifndef _AVG_V
`define _AVG_V

`default_nettype none

`include "ram.v"

// Average over multiple acquisitions of a sample sequence. This
// averages over the inner dimension of the sequence. In other words,
// the first sample of the first sequence is added to the first sample
// of all other sequences and then divided by the total number of
// sequences to find the first sample of the resultant, averaged
// sequence.

// Resource usage:
//
//   - 1 or more BRAM modules, where the number of BRAMs necessary is
//     given by the number required to store (WIDTH + LG_N) x SIZE
//     bits.
//
//   - An adder capable of adding two (WIDTH + LG_N)-bit numbers. This
//     may be 1 or more DSP blocks, or a number of single-bit adders
//     depending on the FPGA architecture.
//
//   - A flip-flop for a single (WIDTH + LG_N)-bit value. This is used
//     for the accumulate operation.
//
//   - A few additional LUTs for control.

module avg #(
   // Bit width of each input (and output) sample.
   parameter WIDTH = 16,
   // Number of samples in a sequence.
   parameter SIZE  = 1024,
   // log2(N) where N is the number of sequences to average
   // over. E.g. a value of 4 will average over 16 sequences. Using a
   // power of 2 makes the implementation more efficient.
   parameter LG_N  = 2
) (
   // Main clock frequency.
   input wire                    clk,
   // Clock enable. Can be used to drive the module slower than would
   // be possible with a system or PLL clock.
   input wire                    clken,
   // Pull high to enable. Settting this to 1'b0 does not clear the
   // internal data, it simply pauses operation. This can be used for
   // instance if there is a time delay between each sample
   // sequence. Use ``rst_n`` to clear the internal data.
   input wire                    en,
   // Clears the internal data and brings the module to a
   // well-defined, initialized state.
   input wire                    rst_n,
   // Input data.
   input wire signed [WIDTH-1:0] din,
   // Output data.
   output reg signed [WIDTH-1:0] dout,
   // Flag indicating valid output data. The state of ``dout`` is
   // undefined when this pin is low.
   output reg                    dvalid
);

   localparam INTERNAL_WIDTH              = WIDTH + LG_N;
   localparam [$clog2(SIZE)-1:0] SIZE_CMP = SIZE - 1;
   localparam N                           = 1 << LG_N;
   localparam [LG_N-1:0] N_CMP            = N - 1;

   wire                          rdwren = en && clken;
   reg [$clog2(SIZE)-1:0]        wraddr;
   reg [$clog2(SIZE)-1:0]        rdaddr;
   reg [LG_N-1:0]                seq_ctr;
   wire signed [INTERNAL_WIDTH-1:0] rddata;
   wire signed [INTERNAL_WIDTH-1:0] wrdata;

   assign wrdata = (seq_ctr == {LG_N{1'b0}}) ? din : rddata + din;

   function [WIDTH-1:0] trunc_to_out(input [INTERNAL_WIDTH-1:0] expr);
      trunc_to_out = expr[INTERNAL_WIDTH-1:LG_N];
   endfunction

   always @(posedge clk) begin
      if (!rst_n) begin
         wraddr  <= {$clog2(SIZE){1'b0}};
         rdaddr  <= {{$clog2(SIZE)-1{1'b0}}, 1'b1};
         seq_ctr <= {LG_N{1'b0}};
         dvalid  <= 1'b0;
      end else if (rdwren) begin
         dout  <= trunc_to_out(wrdata);

         if (wraddr == SIZE_CMP) begin
            wraddr <= {$clog2(SIZE){1'b0}};
            if (seq_ctr == N_CMP) begin
               seq_ctr <= {LG_N{1'b0}};
            end else begin
               seq_ctr <= seq_ctr + 1'b1;
            end
         end else begin
            wraddr <= wraddr + 1'b1;
         end

         if (seq_ctr == N_CMP) begin
            dvalid <= 1'b1;
         end else begin
            dvalid <= 1'b0;
         end

         if (rdaddr == SIZE_CMP) begin
            rdaddr <= {$clog2(SIZE){1'b0}};
         end else begin
            rdaddr <= rdaddr + 1'b1;
         end
      end
   end

   ram #(
      .WIDTH (INTERNAL_WIDTH ),
      .SIZE  (SIZE           )
   ) ram (
      .rdclk  (clk    ),
      .rden   (rdwren ),
      .rdaddr (rdaddr ),
      .rddata (rddata ),
      .wrclk  (clk    ),
      .wren   (rdwren ),
      .wraddr (wraddr ),
      .wrdata (wrdata )
   );

`ifdef COCOTB_SIM
   `ifdef AVG
   initial begin
      $dumpfile ("cocotb/build/avg.vcd");
      $dumpvars (0, avg);
      #1;
   end
   `endif
`endif

endmodule
`endif
