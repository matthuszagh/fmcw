`default_nettype none

`include "fmcw_defines.vh"
`include "downsample.v"

`timescale 1ns/1ps
module downsample_tb #( `FMCW_DEFAULT_PARAMS );

        reg clk_i = 0;
        wire clk_o;
        reg [OW-1:0] data_i = 0;
        wire [OW-1:0] data_o;

        initial begin
                $dumpfile("downsample.vcd");
                $dumpvars(0, downsample_tb);

                #10000 $finish;
        end

        always @(posedge clk_i) begin
                data_i <= data_i + 1;
        end

        always #12.5 clk_i = !clk_i;

        downsample downsample (.clk_i(clk_i),
                               .clk_o(clk_o),
                               .data_i(data_i),
                               .data_o(data_o));

endmodule // downsample_tb
