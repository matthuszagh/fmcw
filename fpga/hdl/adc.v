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



endmodule // adc
