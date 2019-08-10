`default_nettype none

`include "../fmcw_defines.vh"
`include "../kaiser.v"

`timescale 1ns/1ps
module kaiser_tb #( `FMCW_DEFAULT_PARAMS );

        reg clk = 0;
        reg [OW-1:0] data_i = 100;
        wire [OW-1:0] data_o;

        initial begin
                $dumpfile("kaiser.vcd");
                $dumpvars(0, kaiser_tb);

                #10000 $finish;
        end

        always #25 clk = !clk;

        kaiser kaiser (.clk_i(clk),
                       .data_i(data_i),
                       .data_o(data_o));

endmodule // kaiser_tb
