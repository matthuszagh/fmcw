`default_nettype none

`include "../fmcw_defines.vh"
`include "../fir.v"

`timescale 1ns/1ps
module fir_tb #( `FMCW_DEFAULT_PARAMS );

        reg clk = 0;
        reg [IW-1:0] data_i = 1<<11;
        // reg [IW-1:0] data_i = {{IW-1{1'b0}},1'b1};
        wire [OW-1:0] data_o;

        initial begin
                $dumpfile("fir.vcd");
                $dumpvars(0, fir_tb);

                #50 data_i = 0;

                #10000 $finish;
        end

        always #25 clk = !clk;

        fir fir (.clk(clk),
                 .rst(1'b1),
                 .ce(1'b1),
                 .data_i(data_i),
                 .data_o(data_o));

endmodule // fir_tb
