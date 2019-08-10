`default_nettype none

`include "fmcw_defines.vh"

module kaiser #( `FMCW_DEFAULT_PARAMS )
        (
         input wire           clk_i,
         input wire [OW-1:0]  data_i,
         output wire [OW-1:0] data_o
         );

        reg [TW-1:0]         h [0:999];
        reg [2*TW-1:0]       y;
        reg [9:0]            cnt;

        initial begin
                $readmemh("kaiser.hex", h);
                y   = 0;
                cnt = 0;
        end

        // TODO do I need to wait for the first signal?
        always @(posedge clk_i) begin
                if (cnt == 999) begin
                        cnt <= 0;
                end
                else begin
                        cnt <= cnt + 1;
                end
                y <= (data_i * h[cnt])>>TW;
        end

        assign data_o = y[TW-1:0];

endmodule // kaiser
