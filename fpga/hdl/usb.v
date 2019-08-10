`default_nettype none

`include "fmcw_defines.vh"

module usb #( `FMCW_DEFAULT_PARAMS )
        (
         inout wire [USBDW-1:0] data_io,
         output reg [USBDW-1:0] rdata_o,
         input wire [USBDW-1:0] wdata_i,
         input wire             rxf_n_i,
         input wire             txe_n_i,
         output reg             rd_n_o,
         output reg             wr_n_o,
         output reg             siwua_n_o,
         input wire             clk_i,
         output reg             oe_n_o,
         input wire             suspend_n_i,
         input wire             clk_data /* 2MHz clock. */
         );

        // `cnt' keeps track of tx data. When it reaches 0, it means all
        // 8 bits have been sent and we should stop sending data.
        reg [2:0]               cnt;
        wire                    cnt_rst; /* 0 when cnt is 0. */
        // `new_data' signals that new data is available to be sent to
        // the host PC.
        reg                     new_data;

        initial begin
                rdata_o   = {USBDW{1'b0}};
                rd_n_o    = 1;
                wr_n_o    = 1;
                siwua_n_o = 1; /* Never signal to wake-up host PC. */
                cnt       = {3{1'b0}};
                new_data  = 0;
        end

        assign data_io = (!txe_n_i && !wr_n_o) ? wdata_i : {USBDW{1'bz}};
        assign cnt_rst = (!cnt[0] && !cnt[1] && !cnt[2]) ? 0 : 1;

        always @(posedge clk_data, negedge cnt_rst) begin
                if (clk_data) begin
                        new_data <= 1;
                end
                else begin /* cnt_rst = 0 */
                        new_data <= 0;
                end
        end

        always @(posedge clk_i, negedge suspend_n_i) begin
                if (!suspend_n_i) begin
                        wr_n_o  <= 1;
                        rd_n_o  <= 1;
                        oe_n_o  <= 1;
                        rdata_o <= {USBDW{1'b0}};
                        cnt     <= {3{1'b0}};
                end
                else begin
                        // Give TX bus precedence.
                        if (!txe_n_i && new_data) begin
                                wr_n_o  <= 0;
                                rd_n_o  <= 1;
                                oe_n_o  <= 1;
                                rdata_o <= {USBDW{1'b0}};
                                cnt     <= cnt + 1;
                        end
                        // oe_n_o must be driven low at least one period before we can read.
                        else if (!rxf_n_i && oe_n_o) begin
                                wr_n_o  <= 1;
                                rd_n_o  <= 1;
                                oe_n_o  <= 0;
                                rdata_o <= {USBDW{1'b0}};
                                cnt     <= 0;
                        end
                        else if (!rxf_n_i && !oe_n_o) begin
                                wr_n_o  <= 1;
                                rd_n_o  <= 0;
                                oe_n_o  <= 0;
                                rdata_o <= data_io;
                                cnt     <= 0;
                        end
                        else begin
                                wr_n_o  <= 1;
                                rd_n_o  <= 1;
                                oe_n_o  <= 1;
                                rdata_o <= {USBDW{1'b0}};
                                cnt     <= 0;
                        end
                end // else: !if(!suspend_n_i)
        end

endmodule // usb
