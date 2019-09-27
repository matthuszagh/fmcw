`default_nettype none

module adf4158 #(
   // TODO make these localparam
   parameter [1:0] CONFIG_STATE  = 2'd0,
   parameter [1:0] ENABLE_STATE  = 2'd1,
   parameter [1:0] DISABLE_STATE = 2'd2,
   parameter [1:0] IDLE_STATE    = 2'd3
) (
   input wire clk_i, /* 40MHz reference clock. */
   input wire clk_20mhz_i,
   // I use 2 ce's because I don't see much point in powering down the
   // device, but I do need to control when it runs.

   // Pulling ce_i high activates the ramp signal (must wait for
   // `config_done_o' to be pulled high). Pulling it low deactivates
   // the ramp but does not turn off the device.
   input wire ce_i,
   // output reg       ce_o = 1'b1, /* Low voltage powers down device. */
   // input wire [1:0] state_i,
   // Signals data has finished writing to registers. Used for both
   // initial configuration and for subsequent soft enables and
   // disables.
   output reg config_done_o = 1'b0,
   output reg le_o = 1'b1, /* Low when writing data and pull high to flush to internal registers. */
   input wire muxout_i,
   output reg txdata_o = 1'b0,
   output reg data_o = 1'b0 /* Configuration registers data. */
);

   localparam RAMP_EN_INIT = 1'b0;
   localparam RAMP_STEPS  = 20'd1024;
   localparam DELAY_STEPS = 12'd4;
   reg        ramp_en     = RAMP_EN_INIT;

   /* Configuration registers.
    *  Initialization sequence: r7, r6_0, r6_1, r5_0, r5_1, r4, r3, r2, r1, r0
    */
   reg [31:0] r [0:9];

   initial begin
      r[0] = {RAMP_EN_INIT, 4'd15, 12'd265, 12'd0, 3'd0};
      r[1] = {4'd0, 13'd0, 12'd0, 3'd1};
      r[2] = {3'd0, 1'd1, 4'd0, 1'd0, 1'd1, 1'd1, 1'd0, 5'd1, 12'd10, 3'd2};
      r[3] = {16'd0, 1'd0, 1'd0, 2'd0, 2'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 3'd3};
      r[4] = {1'd0, 5'd0, 1'd0, 2'd0, 2'd3, 2'd3, 12'd1, 4'd0, 3'd4};
      r[5] = {2'd0, 1'd0, 1'd0, 2'd0, 1'd0, 1'd0, 1'd1, 4'd4, 16'd31457, 3'd5}; /* reg 5 part 2 */
      r[6] = {2'd0, 1'd0, 1'd0, 2'd0, 1'd0, 1'd0, 1'd0, 4'd4, 16'd31457, 3'd5}; /* reg 5 part 1 */
      r[7] = {8'd0, 1'd1, RAMP_STEPS, 3'd6}; /* reg 6 part 2 */
      r[8] = {8'd0, 1'd0, RAMP_STEPS, 3'd6}; /* reg 6 part 1 */
      r[9] = {13'd0, 1'd0, 1'd1, 1'd1, 1'd0, DELAY_STEPS, 3'd7}; /* reg 7 */
   end

   always @(posedge clk_i) begin
      r[0] <= {ramp_en, r[0][30:0]};
   end

   reg [3:0]  reg_ctr = 4'd9;
   reg [4:0]  bit_ctr = 5'd31;
   // only want to configure this once, unless we power cycle the
   // chip.
   reg        configured = 1'b0;
   reg        enabled    = 1'b0;
   reg        le_delay   = 1'b0;
   reg [1:0]  state      = IDLE_STATE;

   // write configuration data
   always @(negedge clk_20mhz_i) begin
      data_o <= r[reg_ctr][bit_ctr];

      case (state)
      CONFIG_STATE:
        begin
           bit_ctr <= bit_ctr - 5'd1;
           le_o    <= 1'b0;

           if (reg_ctr == 4'd0 && bit_ctr == 5'd0) begin
              le_delay <= 1'b1;
              if (le_delay) begin
                 state         <= ENABLE_STATE;
                 le_delay      <= 1'b0;
                 le_o          <= 1'b1;
                 configured    <= 1'b1;
                 ramp_en       <= 1'b1;
              end else begin
                 bit_ctr       <= bit_ctr;
              end
           end else if (bit_ctr == 5'd0) begin // if (reg_ctr == 4'd0 && bit_ctr == 5'd0)
              le_delay <= 1'b1;
              if (le_delay) begin
                 reg_ctr  <= reg_ctr - 4'd1;
                 le_delay <= 1'b0;
                 le_o     <= 1'b1;
              end else begin
                 bit_ctr <= bit_ctr;
              end
           end
        end
      ENABLE_STATE:
        begin
           bit_ctr <= bit_ctr - 5'd1;
           le_o    <= 1'b0;
           ramp_en <= 1'b1;
           if (ramp_en) begin
              if (bit_ctr == 5'd0) begin
                 le_delay <= 1'b1;
                 if (le_delay) begin
                    state         <= IDLE_STATE;
                    enabled       <= 1'b1;
                    le_delay      <= 1'b0;
                    le_o          <= 1'b1;
                    config_done_o <= 1'b1;
                 end else begin
                    bit_ctr <= bit_ctr;
                 end
              end
           end
        end
      DISABLE_STATE:
        begin
           bit_ctr <= bit_ctr - 5'd1;
           le_o    <= 1'b0;
           ramp_en <= 1'b0;
           if (!ramp_en) begin
              if (bit_ctr == 5'd0) begin
                 le_delay <= 1'b1;
                 if (le_delay) begin
                    state         <= IDLE_STATE;
                    enabled       <= 1'b0;
                    le_delay      <= 1'b0;
                    le_o          <= 1'b1;
                    config_done_o <= 1'b1;
                 end else begin
                    bit_ctr <= bit_ctr;
                 end
              end
           end // if (!ramp_en)
        end
      IDLE_STATE:
        begin
           le_o <= 1'b1;
           if (ce_i && !configured)
             state <= CONFIG_STATE;
           else if (ce_i && !enabled)
             state <= ENABLE_STATE;
           else if (!ce_i && enabled)
             state <= DISABLE_STATE;
        end
      endcase // case (state)
   end

endmodule // adf4158
