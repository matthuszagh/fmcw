`default_nettype none

`include "fmcw_defines.vh"

module adf4158 #( `FMCW_DEFAULT_PARAMS )
        (
         input wire  clk_i, /* 40MHz reference clock. */
         output reg  ce_o, /* Low voltage powers down device. */
         output reg  le_o, /* Low when writing data and pull high to flush to internal registers. */
         output reg  clk_o, /* 20MHz. Synchronizes data loaded into configuration registers. */
         input wire  muxout_i,
         output reg  txdata_o,
         output wire data_o /* Configuration registers data. */
         );

        initial begin
                ce_o = 1'b1;
                le_o = 1'b1;
                clk_o = 1'b0;
                txdata_o = 1'b0;
        end

        assign data_o = (!le_o) ? r[reg_cnt-1][bit_cnt] : 1'b0;

        /* Configuration registers.
         *  Initialization sequence: r7, r6_0, r6_1, r5_0, r5_1, r4, r3, r2, r1, r0
         */
        reg [31:0] r [0:9];

        initial begin
                r[0] = {1'd1, 4'd15, 12'd265, 12'd0, 3'd0};
                r[1] = {4'd0, 13'd0, 12'd0, 3'd1};
                r[2] = {3'd0, 1'd1, 4'd0, 1'd0, 1'd1, 1'd1, 1'd0, 5'd1, 12'd10, 3'd2};
                r[3] = {16'd0, 1'd0, 1'd0, 2'd0, 2'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 3'd3};
                r[4] = {1'd0, 5'd0, 1'd0, 2'd0, 2'd3, 2'd3, 12'd1, 4'd0, 3'd4};
                r[5] = {2'd0, 1'd0, 1'd0, 2'd0, 1'd0, 1'd0, 1'd1, 4'd4, 16'd31457, 3'd5};
                r[6] = {2'd0, 1'd0, 1'd0, 2'd0, 1'd0, 1'd0, 1'd0, 4'd4, 16'd31457, 3'd5};
                r[7] = {8'd0, 1'd1, 20'd2000, 3'd6};
                r[8] = {8'd0, 1'd0, 20'd2000, 3'd6};
                r[9] = {13'd0, 1'd0, 1'd1, 1'd1, 1'd0, 12'd4000, 3'd7};
        end

        localparam num_regs = 10;
        reg [3:0]  reg_cnt = 4'd10;
        reg [4:0]  bit_cnt = 5'd31;
        wire       done = (reg_cnt == 4'd0) ? 1'b1 : 1'b0;
        reg        delay = 1'b0;

        always @(posedge clk_i) begin
                if (!done && !delay) begin
                        le_o <= 1'b0;
                end
                else begin
                        le_o <= 1'b1;
                end

                if (!le_o) begin
                        clk_o <= !clk_o;
                end
                else begin
                        clk_o <= 1'b0;
                end

                if (bit_cnt == 5'd0) begin
                        delay <= 1'b1;
                end
                else begin
                        delay <= 1'b0;
                end
        end

        always @(negedge clk_o) begin
                if (!le_o) begin
                        bit_cnt <= bit_cnt - 5'd1;
                        reg_cnt <= reg_cnt;
                end
                else begin
                        bit_cnt <= 5'd31;
                        reg_cnt <= reg_cnt - 4'd1;
                end
        end

endmodule // adf4158
