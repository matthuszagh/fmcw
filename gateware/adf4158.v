`ifndef _ADF4158_V_
`define _ADF4158_V_

`timescale 1ns/1ps
`default_nettype none

// `adf4158' can be used to configure and control an ADF4158 frequency
// synthesizer.

// TODO Currently, this module is limited in the fact that it's only
// configurable at synthesis time. Future iterations should support
// live reconfiguration.

// Relevant equations (taken from datasheet and provided here for
// convenience):
//
// (1) f_PFD = clk x [(1 + DOUBLER) / (R_COUNTER x (1 + RDIV2))]
//     f_PFD is the PFD reference frequency.
//     default params: 20MHz
//
// (2) RF_OUT = f_PFD x (INT + (FRAC / 2^25))
//     RF_OUT is the external VCO output frequency.
//     default params: 5.3GHz
//
// (3) Timer = CLK1_DIV x CLK2_DIV x (1 / f_PFD)
//     Timer is the time between each frequency step in a ramp.
//     default params: 0.5us
//
// (4) f_DEV = (f_PFD / 2^25) x (DEV x 2^DEV_OFFSET)
//     f_DEV determines the frequency increment in each ramp step.
//     default params: 300kHz
//
// (5) Delay = (1 / f_PFD) x CLK1_DIV x Delay Start Word
//     The delay between ramps (this version uses CLK1_DIV for an
//     additional delay).
//     default params: 2ms

// Ports:
// clk        : A 40MHz input reference clock.
// clk_20mhz  : 20MHz clock used to synchronize configuration data.
// rst_n      : Active low reset. After performing a reset, the device
//              must be fully reconfigured.
// enable     : 1 activates the frequency ramp and 0 disables it. You
//              must wait for `config_done' to go high before the ramp
//              is active.
// le         : Low when writing data to ADF4158 and high to flush the
//              data. This should be connected directly to the
//              corresponding pin on the device.
// ce         : 0 powers down the device. This is triggered when an
//              active low reset is called. If you simply wish to
//              disable the device, use `enable' rather than `rst_n'.
// muxout     : Pulses high at the end of the ramp period (see p.30 of
//              the datasheet). This is used to synchronize data
//              acquisition with the frequency ramp, based on the fact
//              we've scheduled a delay between ramps of 2ms.
// ramp_start : Pulses high for one clk period to signal the start of the
//              ramp period.
// ramp_on    : High when the ramp is on and low when off.
// txdata     : TODO
// data       : Serial configuration data for ADF4158 internal
//              registers. Connect directly to corresponding device pin.

// To determine the internal state of the ADF4158, look at the
// descriptions next to MUXOUT, INTERRUPT and READBACK_MUXOUT. Also
// see p31 of the datasheet, which provides the timing diagrams.

module adf4158 #(
   // Initializes the ramp enable bit which enables a frequency
   // ramp. When set to 0, the VCO output frequency stays at the
   // center frequency determined by RF_OUT. When set to 1, the
   // frequency ramps according the ramp parameters set. Initialize
   // this to 0, and then set it to 1 later with `ramp_en'.
   parameter [0:0] RAMP_EN_INIT     = 1'b0,
   // Sets which internal data is readback on the muxout pin. The
   // default sets this to digital lock detect, which indicates
   // whether the PLL frequency is locked. If using READBACK_MUXOUT,
   // this must be set to 4'b1111. For other values, see the
   // datasheet.
   parameter [3:0] MUXOUT           = 4'b1111,
   // Frequency multiplier for VCO output frequency. See eqn (2).
   parameter [11:0] INT             = 12'd265,
   // Fractional value used in determining the VCO output
   // frequency. See eqn (2).
   parameter [24:0] FRAC            = 25'd0,
   // Reference doubler. Can only be used when the input reference
   // frequency is no greater than 30MHz. See eqn (1).
   parameter [0:0] DOUBLER          = 1'b0,
   // The R-Counter divides REF_IN (`clk' input) to produce the
   // reference clock for the PFD. See eqn (1).
   parameter [4:0] R_COUNTER        = 5'd1,
   // The R-Divider. Setting this to 1 can be used with cycle slip
   // reduction. See eqn (1).
   parameter [0:0] RDIV2            = 1'b1,
   // Enable cycle slip reduction, which improves frequency lock
   // times. To be used, the PFD reference frequency must have a 50%
   // duty cycle, CP_CURRENT must be 0, and PD must be 1.
   parameter [0:0] CSR_EN           = 1'b1,
   // Charge pump current setting.
   parameter [3:0] CP_CURRENT       = 4'd0,
   // Prescale. Must be set to 1 for freq > 3GHz.
   parameter [0:0] PRESCALER        = 1'b1,
   // Clock 1 divider. Determines the duration of a ramp step in ramp
   // mode. See eqn (3).
   parameter [11:0] CLK1_DIV        = 12'd10,
   // N SEL prevents INT and FRAC from loading at different times and
   // causing a frequency overshoot. Set to 1 to use.
   parameter [0:0] N_SEL            = 1'b1,
   // Resets the Sigma-Delta modulator on each write to R0. Set to 1
   // to use. This generally does not need to be set.
   parameter [0:0] SD_RESET         = 1'b0,
   // Sets the ramp mode. See datasheet for available modes. The
   // default (2'b00) sets the ramp mode to continous sawtooth.
   parameter [1:0] RAMP_MODE        = 2'b00,
   // Set to 1 to enable PSK modulation.
   parameter [0:0] PSK_EN           = 1'b0,
   // Set to 1 to enable FSK modulation.
   parameter [0:0] FSK_EN           = 1'b0,
   // Lock detect precision determines the number of consecutive PFD
   // cycles that must pass before the digital lock detect is
   // set. Setting this to 0 uses lower precision (24 cycles of
   // 15ns). Setting to 1 uses higher precision (40 cycles of 15ns).
   parameter [0:0] LDP              = 1'b0,
   // Phase detector polarity. Set this to 1 when the VCO output
   // changes positively with positive changes in input. Set this to 0
   // if changes to the VCO's output and input are inversely related.
   parameter [0:0] PD               = 1'b1,
   // Software power-down. This disables the frequency output but
   // registers maintain state and remain capable of loading new
   // values. Setting this bit to 1 performs a power down.
   parameter [0:0] PWR_DWN_INIT     = 1'b0,
   // Places the charge pump in 3-state mode when set to 1. Set this
   // to 0 for normal operation.
   parameter [0:0] CP3              = 1'b0,
   // Set to 1 to reset the RF synthesizer counters. This should be
   // set to 0 when in normal operation.
   parameter [0:0] COUNTER_RST_INIT = 1'b0,
   // Load enable select. Setting this to 1 enables it. See datasheet
   // for information.
   parameter [0:0] LE_SEL           = 1'b0,
   // Sets the Delta-Sigma modulator mode. Set to 5'b0_0000 for normal
   // operation. See the datasheet for alternative operating states.
   parameter [4:0] DELTA_SIGMA      = 5'b0_0000,
   // Setting the negative bleed current to 2'b11 enables constant
   // negative bleed current which ensures the charge pump operates
   // outside its dead zone. Set this to 2'b00 to disable it. If this
   // is enabled, READBACK_MUXOUT must be disabled.
   parameter [1:0] BLEED_CURRENT    = 2'b00,
   // Enables reading back the synthesizer's frequency at the moment
   // of interrupt. Set this to 2'b00 to disable, or 2'b10 to enable.
   parameter [1:0] READBACK_MUXOUT = 2'b11,
   // Setting clock divider mode to 2'b11 enables ramping. If instead
   // you want the fast-lock mode, set this to 2'b01.
   parameter [1:0] CLK_DIV_MODE    = 2'b11,
   // Clock 2 divider. Determines the duration of a ramp step in ramp
   // mode. See eqn (3).
   parameter [11:0] CLK2_DIV        = 12'd1,
   // Set this to 0 to use the clock divider clock for clocking a
   // ramp. Set this to 1 to use the TX data clock instea.
   parameter [0:0] TX_RAMP_CLK      = 1'b0,
   // 0 disables a parabolic ramp. 1 enables it.
   parameter [0:0] PAR_RAMP         = 1'b0,
   // Determines the type of interrupt used. This can be used with the
   // READBACK_MUXOUT function to read back INT and FRAC at the moment
   // of interrupt. The rising edge of tx_data triggers the interrupt,
   // and the interrupt finishes when the readback is finished. Set
   // this to 2'b00 to disable interrupts. 2'b01 continues the sweep
   // at its last value prior to interrupt. 2'b11 freezes the sweep at
   // that value.
   parameter [1:0] INTERRUPT        = 2'b00,
   // Setting this to 1 enables the FSK ramp. 0 disables it.
   parameter [0:0] FSK_RAMP_EN      = 1'b0,
   // Setting this to 1 enables the second ramp. 0 disables it.
   parameter [0:0] RAMP2_EN         = 1'b0,
   // The deviation offset sets the frequency ramp step. See eqn (4)
   // for details.
   parameter [3:0] DEV_OFFSET       = 4'd4,
   // Determines the frequency ramp step. See eqn (4) for details.
   parameter [15:0] DEV             = 16'd31457,
   // Sets the number of steps in a ramp. Each step has frequency
   // increment f_DEV (eqn 4) and time step timer (eqn 3).
   parameter RAMP_STEPS             = 20'd2000,
   // Setting this to 1 enables the ramp delay fast lock function.
   parameter [0:0] RAMP_DEL_FST_LCK = 1'b0,
   // Setting this to 1 enables a delay between ramp bursts. Note that
   // this does not disable frequency output (use PWR_DWN_INIT for
   // that), it simply holds the frequency output at its RF_OUT value.
   parameter [0:0] RAMP_DELAY       = 1'b1,
   // Setting this to 0 selects the f_PFD clock as the delay
   // clock. Setting this 1 uses f_PFD / CLK1_DIV as delay clock
   // frequency.
   parameter [0:0] DELAY_CLK_SEL    = 1'b1,
   // 1 enables a delayed start.
   parameter [0:0] DELAY_START_EN   = 1'b0,
   // Sets the number of steps in a delay.
   parameter [11:0] DELAY_STEPS     = 12'd4000
) (
   input wire clk,
   input wire clk_20mhz,
   input wire rst_n,
   input wire enable,
   output reg config_done,
   output reg le,
   output reg ce,
   input wire muxout,
   output reg ramp_start,
   output reg ramp_on,
   output reg txdata,
   output reg data
);

   // TODO disable and enable should be updated to use the soft
   // power-down facility. See parameter `PWR_DWN_INIT'. It's probably
   // a good idea to reset the frequency counters as well (see
   // parameter `COUNTER_RST_INIT').
   localparam [1:0] CONFIG_STATE  = 2'd0;
   localparam [1:0] ENABLE_STATE  = 2'd1;
   localparam [1:0] DISABLE_STATE = 2'd2;
   localparam [1:0] IDLE_STATE    = 2'd3;

   reg        ramp_en;

   /* Configuration registers.
    * Initialization sequence: r7, r6_0, r6_1, r5_0, r5_1, r4, r3, r2, r1, r0
    */
   reg [31:0] r [0:9];

   initial begin
      r[0] = {RAMP_EN_INIT, MUXOUT, INT, FRAC[24:13], 3'd0};
      r[1] = {4'd0, FRAC[12:0], 12'd0, 3'd1};
      r[2] = {3'd0, CSR_EN, CP_CURRENT, 1'd0, PRESCALER, RDIV2, DOUBLER, R_COUNTER, CLK1_DIV, 3'd2};
      r[3] = {16'd0, N_SEL, SD_RESET, 2'd0, RAMP_MODE, PSK_EN, FSK_EN, LDP, PD, PWR_DWN_INIT, CP3, COUNTER_RST_INIT, 3'd3};
      r[4] = {LE_SEL, DELTA_SIGMA, 1'd0, BLEED_CURRENT, READBACK_MUXOUT, CLK_DIV_MODE, CLK2_DIV, 4'd0, 3'd4};
      r[5] = {2'd0, TX_RAMP_CLK, PAR_RAMP, INTERRUPT, FSK_RAMP_EN, RAMP2_EN, 1'd1, DEV_OFFSET, DEV, 3'd5}; /* reg 5 part 2 */
      r[6] = {2'd0, TX_RAMP_CLK, PAR_RAMP, INTERRUPT, FSK_RAMP_EN, RAMP2_EN, 1'd0, DEV_OFFSET, DEV, 3'd5}; /* reg 5 part 1 */
      r[7] = {8'd0, 1'd1, RAMP_STEPS, 3'd6}; /* reg 6 part 2 */
      r[8] = {8'd0, 1'd0, RAMP_STEPS, 3'd6}; /* reg 6 part 1 */
      r[9] = {13'd0, RAMP_DEL_FST_LCK, RAMP_DELAY, DELAY_CLK_SEL, DELAY_START_EN, DELAY_STEPS, 3'd7}; /* reg 7 */
   end

   always @(posedge clk) begin
      r[0] <= {ramp_en, r[0][30:0]};
   end

   // signal ramp start signal for control logic.

   // TODO this isn't properly parameterized because it isn't
   // necessarily consistent with the module parameters.
   localparam DELAY_PERIODS = 80000;
   localparam [$clog2(DELAY_PERIODS-1)-1:0] DELAY_PERIODS_CMP = DELAY_PERIODS - 1;
   reg [$clog2(DELAY_PERIODS)-1:0] delay_ctr;

   always @(posedge clk) begin
      if (!rst_n) begin
         delay_ctr  <= {$clog2(DELAY_PERIODS){1'b0}};
         ramp_start <= 1'b0;
         ramp_on    <= 1'b0;
      end else begin
         if (delay_ctr == {$clog2(DELAY_PERIODS){1'b0}}) begin
            ramp_start <= 1'b0;
            ramp_on    <= 1'b1;
            if (muxout) begin
               delay_ctr <= {{$clog2(DELAY_PERIODS)-1{1'b0}}, 1'b1};
            end else begin
               delay_ctr <= {$clog2(DELAY_PERIODS){1'b0}};
            end
         end else begin
            if (delay_ctr == DELAY_PERIODS_CMP) begin
               delay_ctr  <= {$clog2(DELAY_PERIODS){1'b0}};
               ramp_start <= 1'b1;
               ramp_on    <= 1'b1;
            end else begin
               delay_ctr  <= delay_ctr + 1'b1;
               ramp_start <= 1'b0;
               ramp_on    <= 1'b0;
            end
         end
      end
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
                 config_done <= 1'b0;
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
                 config_done <= 1'b0;
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
                 if (enable && !configured) begin
                    state <= CONFIG_STATE;
                    config_done <= 1'b0;
                 end else if (enable && !enabled) begin
                    state <= ENABLE_STATE;
                    config_done <= 1'b0;
                 end else if (enable && enabled) begin
                    state <= IDLE_STATE;
                    config_done <= 1'b1;
                 end else if (!enable && enabled) begin
                    state <= DISABLE_STATE;
                    config_done <= 1'b0;
                 end else if (!enable && !enabled) begin
                    state <= IDLE_STATE;
                    config_done <= 1'b1;
                 end
              end
            endcase
         end
      end
   end

endmodule

`ifdef ADF4158_SIMULATE

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
`endif
