`default_nettype none

// `adf4158' can be used to configure and control an ADF4158 frequency
// synthesizer.

// Ports:
// clk       : A 40MHz input reference clock.
// clk_20mhz : 20MHz clock used to synchronize configuration data.
// rst_n     : Active low reset. After performing a reset, the device
//             must be fully reconfigured.
// enable    : 1 activates the frequency ramp and 0 disables it. You
//             must wait for `config_done' to go high before the ramp
//             is active.
// le        : Low when writing data to ADF4158 and high to flush the
//             data. This should be connected directly to the
//             corresponding pin on the device.
// ce        : 0 powers down the device. This is triggered when an
//             active low reset is called. If you simply wish to
//             disable the device, use `enable' rather than `rst_n'.
// muxout    : TODO
// txdata    : TODO
// data      : Serial configuration data for ADF4158 internal
//             registers. Connect directly to corresponding device pin.

module adf4158 (
   input wire clk,
   input wire clk_20mhz,
   input wire rst_n,
   input wire enable,
   output reg config_done,
   output reg le,
   output reg ce,
   input wire muxout,
   output reg txdata,
   output reg data
);

   localparam [1:0] CONFIG_STATE  = 2'd0;
   localparam [1:0] ENABLE_STATE  = 2'd1;
   localparam [1:0] DISABLE_STATE = 2'd2;
   localparam [1:0] IDLE_STATE    = 2'd3;

   localparam RAMP_EN_INIT = 1'b0;
   localparam RAMP_STEPS   = 20'd1024;
   localparam DELAY_STEPS  = 12'd4;
   localparam DELAY_EN     = 1'b0;
   reg        ramp_en;

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
      r[9] = {13'd0, 1'd0, DELAY_EN, 1'd1, 1'd0, DELAY_STEPS, 3'd7}; /* reg 7 */
   end

   always @(posedge clk) begin
      r[0] <= {ramp_en, r[0][30:0]};
   end

   reg [3:0]  reg_ctr;
   reg [4:0]  bit_ctr;
   // only want to configure this once, unless we power cycle the
   // chip.
   reg        configured;
   reg        enabled;
   reg        le_delay;
   reg [1:0]  state;

   // write configuration data
   always @(negedge clk_20mhz) begin
      if (!rst_n) begin
         state       <= IDLE_STATE;
         ce          <= 1'b0;
         le          <= 1'b1;
         le_delay    <= 1'b0;
         enabled     <= 1'b0;
         configured  <= 1'b0;
         bit_ctr     <= 5'd31;
         reg_ctr     <= 4'd9;
         ramp_en     <= RAMP_EN_INIT;
         txdata      <= 1'b0;
         config_done <= 1'b0;
      end else begin
         data <= r[reg_ctr][bit_ctr];
         ce   <= 1'b1;

         if (ce) begin
            case (state)
            CONFIG_STATE:
              begin
                 bit_ctr <= bit_ctr - 5'd1;
                 le      <= 1'b0;

                 if (reg_ctr == 4'd0 && bit_ctr == 5'd0) begin
                    le_delay <= 1'b1;
                    if (le_delay) begin
                       state         <= ENABLE_STATE;
                       le_delay      <= 1'b0;
                       le            <= 1'b1;
                       configured    <= 1'b1;
                       ramp_en       <= 1'b1;
                    end else begin
                       bit_ctr       <= bit_ctr;
                    end
                 end else if (bit_ctr == 5'd0) begin
                    le_delay <= 1'b1;
                    if (le_delay) begin
                       reg_ctr  <= reg_ctr - 4'd1;
                       le_delay <= 1'b0;
                       le       <= 1'b1;
                    end else begin
                       bit_ctr <= bit_ctr;
                    end
                 end
              end
            ENABLE_STATE:
              begin
                 bit_ctr <= bit_ctr - 5'd1;
                 le      <= 1'b0;
                 ramp_en <= 1'b1;
                 if (ramp_en) begin
                    if (bit_ctr == 5'd0) begin
                       le_delay <= 1'b1;
                       if (le_delay) begin
                          state       <= IDLE_STATE;
                          enabled     <= 1'b1;
                          le_delay    <= 1'b0;
                          le          <= 1'b1;
                          config_done <= 1'b1;
                       end else begin
                          bit_ctr <= bit_ctr;
                       end
                    end
                 end
              end
            DISABLE_STATE:
              begin
                 bit_ctr <= bit_ctr - 5'd1;
                 le      <= 1'b0;
                 ramp_en <= 1'b0;
                 if (!ramp_en) begin
                    if (bit_ctr == 5'd0) begin
                       le_delay <= 1'b1;
                       if (le_delay) begin
                          state       <= IDLE_STATE;
                          enabled     <= 1'b0;
                          le_delay    <= 1'b0;
                          le          <= 1'b1;
                          config_done <= 1'b1;
                       end else begin
                          bit_ctr <= bit_ctr;
                       end
                    end
                 end
              end
            IDLE_STATE:
              begin
                 le <= 1'b1;
                 if (enable && !configured)
                   state <= CONFIG_STATE;
                 else if (enable && !enabled)
                   state <= ENABLE_STATE;
                 else if (!enable && enabled)
                   state <= DISABLE_STATE;
              end
            endcase
         end
      end
   end

endmodule

`ifdef ADF4158_SIMULATE

`timescale 1ns/1ps
module adf4158_tb;

   reg clk = 1'b0;
   reg clk_20mhz = 1'b0;
   reg ce = 1'b1;
   wire le;
   wire clk_adf;
   wire txdata;
   wire data;
   reg  rst_n = 1'b0;

   initial begin
      $dumpfile("tb/adf4158_tb.vcd");
      $dumpvars(0, adf4158_tb);
      $dumpvars(0, dut.r[0]);

      #10 rst_n = 1'b1;

      #100000 $finish;
   end

   always #12.5 clk = !clk;
   initial begin
      #12.5 clk_20mhz = 1'b1;
      forever #25 clk_20mhz = !clk_20mhz;
   end

   reg       adf_soft_enable = 1'b0;
   reg       adf_hard_enable = 1'b1;

   always @(posedge clk) begin
      if (ce) begin
         adf_soft_enable = 1'b1;
         adf_hard_enable = 1'b1;
      end else begin
         adf_soft_enable = 1'b0;
         adf_hard_enable = 1'b0;
      end
   end

   wire      adf_config_done;

   adf4158 dut (
      .clk         (clk),
      .clk_20mhz   (clk_20mhz),
      .rst_n       (rst_n),
      .enable      (adf_soft_enable),
      .config_done (adf_config_done),
      .le          (le),
      .txdata      (txdata),
      .data        (data)
   );

endmodule

`endif
