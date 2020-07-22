`ifndef _ADF4158_V_
`define _ADF4158_V_

`timescale 1ns/1ps
`default_nettype none

`include "ff_sync.v"

// This module can be used to configure and control an ADF4158
// frequency synthesizer.

// TODO disable and enable should be updated to use the soft
// power-down facility. See parameter `PWR_DWN_INIT'. It's probably a
// good idea to reset the frequency counters as well (see parameter
// `COUNTER_RST_INIT').

// Relevant equations (taken from datasheet and provided here for
// convenience):
//
// (1) f_PFD = clk x [(1 + DOUBLER) / (R_COUNTER x (1 + RDIV2))]
//     f_PFD is the PFD reference frequency.
//     default params: 20MHz
//
// (2) RF_OUT = f_PFD x (INT + (FRAC / 2^25))
//     RF_OUT is the external VCO output frequency.
//     default params: 5.6GHz
//
// (3) Timer = CLK1_DIV x CLK2_DIV x (1 / f_PFD)
//     Timer is the time between each frequency step in a ramp.
//     default params: 0.5us
//
// (4) f_DEV = (f_PFD / 2^25) x (DEV x 2^DEV_OFFSET)
//     f_DEV determines the frequency increment in each ramp step.
//     default params: 150kHz
//
// (5) Delay = (1 / f_PFD) x CLK1_DIV x DELAY_STEPS
//     The delay between ramps (this version uses CLK1_DIV for an
//     additional delay).
//     default params: 2ms

// TODO some ports are missing or wrong
// Ports:
// clk        : A 40MHz input reference clock.
// clk20      : 20MHz clock used to synchronize configuration data.
// arst_n     : Active low asynchronous reset. This is not a typical
//              reset in the sense that it does not simply clear some
//              register values. Instead, it disables the ramp and
//              places the synthesizer into an initial state. Note
//              this only has an effect when the synthesizer is
//              active. This is in a way the opposite of configure.
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
// configure  : When the synthesizer is in an inactive state, this
//              loads the register values into the synthesizer and
//              enables the ramp. This is sort of the opposite of
//              arst_n.
// txdata     : TODO
// data       : Serial configuration data for ADF4158 internal
//              registers. Connect directly to corresponding device pin.

// To determine the internal state of the ADF4158, look at the
// descriptions next to MUXOUT, INTERRUPT and READBACK_MUXOUT. Also
// see p31 of the datasheet, which provides the timing diagrams.

module adf4158 (
   input wire        clk,
   input wire        clk20,
   input wire        arst_n,
   output wire       clk_o,
   input wire        configure,
   input wire        muxout,
   input wire [2:0]  reg_num,
   input wire        load_reg,
   input wire [31:0] reg_val,
   output reg        active = 1'b0,
   output reg        le = 1'b1,
   output reg        ramp_start = 1'b0,
   output reg        ce = 1'b1,
   output reg        txdata = 1'b0,
   output reg        data = 1'b0
);

   assign clk_o = clk20;

   wire              srst_n;
   ff_sync #(
      .WIDTH  (1),
      .STAGES (2)
   ) rst_sync (
      .dest_clk (clk    ),
      .d        (arst_n ),
      .q        (srst_n )
   );

   /* Configuration registers.
    * Initialization sequence: r7, r6_0, r6_1, r5_0, r5_1, r4, r3, r2, r1, r0
    */
   reg [31:0]        r [0:9];
   reg               ramp_en = 1'b0;
   always @(posedge clk) begin
      r[0][31] <= ramp_en;

      r[6][31:24] <= r[5][31:24];
      r[6][23]    <= 1'b0;
      r[6][22:0]  <= r[5][22:0];

      r[8][31:24] <= r[7][31:24];
      r[8][23]    <= 1'b0;
      r[8][22:0]  <= r[7][22:0];

      if (load_reg) begin
         case (reg_num)
         3'd0: r[0][30:0] <= reg_val[30:0];
         3'd1: r[1]       <= reg_val;
         3'd2: r[2]       <= reg_val;
         3'd3: r[3]       <= reg_val;
         3'd4: r[4]       <= reg_val;
         3'd5:
           begin
              r[5][31:24] <= reg_val[31:24];
              r[5][23]    <= 1'b1;  // dev sel
              r[5][22:0]  <= reg_val[22:0];
           end
         3'd6:
           begin
              r[7][31:24] <= reg_val[31:24];
              r[7][23]    <= 1'b1;  // step sel
              r[7][22:0]  <= reg_val[22:0];
           end
         3'd7: r[9] <= reg_val;
         endcase
      end
   end

   reg muxout_last = 1'b0;
   always @(posedge clk) begin
      muxout_last <= muxout;
      ramp_start  <= ~muxout & muxout_last;
   end

   localparam NUM_STATES = 4;
   localparam INACTIVE   = 0,
              CONFIG_LE  = 1,
              CONFIG_DAT = 2,
              ACTIVE     = 3;
   reg [NUM_STATES-1:0] state, next;
   initial begin
      state           = {NUM_STATES{1'b0}};
      state[INACTIVE] = 1'b1;

      next           = {NUM_STATES{1'b0}};
      next[INACTIVE] = 1'b1;
   end

   always @(negedge clk20) begin
      state <= next;
   end

   reg [3:0]  reg_ctr      = 4'd9;
   reg [3:0]  reg_ctr_last = 4'd9;
   reg [4:0]  bit_ctr      = 5'd31;

   always @(*) begin
      next = {NUM_STATES{1'b0}};
      case (1'b1)
      state[INACTIVE]   : if (configure)       next[CONFIG_LE]  = 1'b1;
                          else                 next[INACTIVE]   = 1'b1;
      state[CONFIG_LE]  :
        if (reg_ctr_last == 4'd0) begin
           if (ramp_en)                        next[ACTIVE]     = 1'b1;
           else                                next[INACTIVE]   = 1'b1;
        end
        else                                   next[CONFIG_DAT] = 1'b1;
      state[CONFIG_DAT] : if (bit_ctr == 5'd0) next[CONFIG_LE]  = 1'b1;
                          else                 next[CONFIG_DAT] = 1'b1;
      state[ACTIVE]     : if (~srst_n)         next[INACTIVE]   = 1'b1;
                          else                 next[ACTIVE]     = 1'b1;
      default           :                      next[INACTIVE]   = 1'b1;
      endcase
   end

   always @(negedge clk20) begin
      ce <= 1'b1;
      case (1'b1)
      next[INACTIVE]:
        begin
           reg_ctr_last <= 4'd9;
           reg_ctr      <= 4'd9;
           bit_ctr      <= 5'd31;
           le           <= 1'b1;
           active       <= 1'b0;
           data         <= 1'b0;
           ramp_en      <= 1'b1;
        end
      next[CONFIG_LE]:
        begin
           reg_ctr_last                  <= reg_ctr;
           if (~state[INACTIVE]) reg_ctr <= reg_ctr - 1'b1;
           bit_ctr                       <= 5'd31;
           le                            <= 1'b1;
           active                        <= 1'b0;
           data                          <= 1'b0;
        end
      next[CONFIG_DAT]:
        begin
           if (~state[CONFIG_LE]) bit_ctr <= bit_ctr - 1'b1;
           le                             <= 1'b0;
           active                         <= 1'b0;
           data                           <= r[reg_ctr][bit_ctr-1'b1];
        end
      next[ACTIVE]:
        begin
           reg_ctr_last <= 4'd9;
           reg_ctr      <= 4'd9;
           bit_ctr      <= 5'd31;
           le           <= 1'b1;
           active       <= 1'b1;
           data         <= 1'b0;
           ramp_en      <= 1'b0;
        end
      endcase
   end

endmodule

`ifdef ADF4158_SIMULATE

module adf4158_tb;

   reg clk = 1'b0;
   reg clk20 = 1'b0;
   reg ce = 1'b1;
   wire le;
   wire clk_adf;
   wire txdata;
   wire data;
   reg  rst_n = 1'b0;
   reg  configure = 1'b0;

   initial begin
      $dumpfile("tb/adf4158_tb.vcd");
      $dumpvars(0, adf4158_tb);
      // $dumpvars(0, dut.r[0]);

      #100 configure = 1'b1;
      #100000 $finish;
   end

   always #12.5 clk = !clk;
   initial begin
      #12.5 clk20 = 1'b1;
      forever #25 clk20 = !clk20;
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

   wire      adf_active;

   adf4158 dut (
      .clk       (clk        ),
      .clk20     (clk20      ),
      .configure (configure  ),
      .active    (adf_active ),
      .le        (le         ),
      .txdata    (txdata     ),
      .data      (data       )
   );

endmodule

`endif
`endif
