`default_nettype none

`include "fmcw_defines.vh"

// TODO: This module is not properly parameterized because it only works when OW=2*USBDW. It
// should be rewritten to work under all circumstances.
module data_packer #( `FMCW_DEFAULT_PARAMS )
        (
         input wire             clk_i,
         input wire [OW-1:0]    data_i,
         output reg [USBDW-1:0] data_o
         );

        initial begin
                data_o = {USBDW{1'b0}};
        end

        // Data has 16-bit precision and must be sent over USB in
        // 8-bit bytes. Send the most significant 8 bits first, then
        // the least significant, then the next 16 bit sample, and so
        // on.  `upper' is a control bit. When 1, indicates the upper
        // 8 bits are sent and when 0, indicates lower 8 bits are
        // sent.
        reg upper = 1'b1;

        always @(posedge clk_i) begin
                if (upper) begin
                        upper <= 1'b0;
                        data_o <= data_i[OW-1:USBDW];
                end
                else begin
                        upper <= 1'b1;
                        data_o <= data_i[USBDW-1:0];
                end
        end

endmodule // data_packer
