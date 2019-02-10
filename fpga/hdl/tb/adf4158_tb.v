`default_nettype none

`include "../fmcw_defines.vh"
`include "../adf4158.v"

`timescale 100ps/100ps
module adf4158_tb;

        reg clk = 1'b0;
        wire ce;
        wire le;
        wire clk_adf;
        wire txdata;
        wire data;

        initial begin
                $dumpfile("adf4158.vcd");
                $dumpvars(0, adf4158_tb);

                #1000000 $finish;
        end

        always #125 clk = !clk;

        adf4158 adf4158 (.clk_i(clk),
                         .ce_o(ce),
                         .le_o(le),
                         .clk_o(clk_adf),
                         .txdata_o(txdata),
                         .data_o(data));

endmodule // adf4158_tb
