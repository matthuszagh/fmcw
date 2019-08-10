`default_nettype none

`include "fmcw_defines.vh"

module chan_split #( `FMCW_DEFAULT_PARAMS )
        (
         input wire clk_i,
         output reg clk_o,
         input wire data_i,
         output reg chan_a,
         output reg chan_b
         );

        reg         cnt;

        initial begin
                clk_o = 1'b0;
                cnt = 1'b0;
        end

        always @(posedge clk_i) begin
                if (cnt == 1'b0) begin
                        clk_o <= clk_o;
                        chan_a <= data_i;
                        chan_b <= chan_b;
                end
                else begin
                        clk_o <= !clk_o;
                        chan_a <= chan_a;
                        chan_b <= data_i;
                end
                cnt <= cnt + 1;
        end

endmodule // chan_split
