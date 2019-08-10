`default_nettype none

`include "../fmcw_defines.vh"
`include "../chan_split.v"

`timescale 1ns/1ps
module chan_split_tb #( `FMCW_DEFAULT_PARAMS );

        // reg clk = 0;
        // reg [OW-1:0] data_i = 100;
        // wire [OW-1:0] data_o;

        // initial begin
        //         $dumpfile("chan_split.vcd");
        //         $dumpvars(0, chan_split_tb);

        //         #10000 $finish;
        // end

        // always #25 clk = !clk;

        // chan_split chan_split (.clk_i(clk),
        //                        .data_i(data_i),
        //                        .data_o(data_o));

endmodule // chan_split_tb
