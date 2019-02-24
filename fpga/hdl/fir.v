`default_nettype none

`include "fmcw_defines.vh"

module fir #( `FMCW_DEFAULT_PARAMS )
        (
         input wire           clk,
         input wire           rst,
         input wire           ce,
         input wire [IW-1:0]  data_i,
         output wire [OW-1:0] data_o
         );

        reg [TW-1:0]          h [0:NTAPS-1];
        reg [IntW-1:0]        y [0:NTAPS-1];
        reg [CntW-1:0]        i;

        initial begin
                $readmemh("../fir/taps.hex", h);
                for (i=0; i<NTAPS; i=i+1) begin
                        y[i] = 0;
                end
                i = 0;
        end

        always @(posedge clk, negedge rst) begin
                if (!rst) begin
                        for (i=0; i<NTAPS; i=i+1) begin
                                y[i] <= 0;
                        end
                end else if (ce) begin
                        y[0] <= data_i * h[NTAPS-1];
                        for (i=1; i<NTAPS; i=i+1) begin
                                y[i] <= y[i-1] + (data_i * h[NTAPS-1-i]);
                        end
                end else begin
                        for (i=0; i<NTAPS-1; i=i+1) begin
                                y[i] <= y[i];
                        end
                end
        end

        assign data_o = (y[NTAPS-1]>>OW);

endmodule // fir
