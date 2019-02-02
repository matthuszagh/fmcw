`default_nettype none

`include "fmcw_defines.vh"

module adc #( `FMCW_DEFAULT_PARAMS )
        (
         input wire           clk_i,
         output wire          clk_o,
         input wire [IW-1:0]  data_i,
         output wire [OW-1:0] data_o,
         output wire          valid
         );

        wire [OW-1:0]         data_fir_o;

        always @(posedge clk) begin
                data_a_buf <= data_in;
        end

        always @(negedge clk) begin
                data_b_buf <= data_in;
        end

        fir fir (.clk(clk),
                 .rst(1),
                 .ce(1),
                 .data_i(data_i),
                 .data_o(data_fir_o));

        downsample downsample (.clk_i(clk_i),
                               .clk_o(clk_o),
                               .data_i(data_fir_o),
                               .data_o(data_o));

endmodule // adc
