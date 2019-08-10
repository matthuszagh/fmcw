`default_nettype none

`include "fmcw_defines.vh"

module downsample #( `FMCW_DEFAULT_PARAMS )
        (
         input wire          clk_i,
         output reg          clk_o,
         input wire [OW-1:0] data_i,
         output reg [OW-1:0] data_o
         );

        reg [MW-1:0]         cnt;

        initial begin
                cnt = 0;
                clk_o = 0;
        end

        always @(posedge clk_i) begin
                if (cnt == (M>>1)-1) begin /* M is the downsampling rate */
                        cnt <= 0;
                        clk_o <= !clk_o;
                        data_o <= data_i;
                end
                else begin
                        cnt <= cnt + 1;
                        clk_o <= clk_o;
                        data_o <= data_o;
                end
        end

endmodule // downsample
