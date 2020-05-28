`default_nettype none
`timescale 1ns/1ps

`define GPIO_WIDTH 6
`define USB_DATA_WIDTH 8
`define ADC_DATA_WIDTH 12
`define SD_DATA_WIDTH 4
`define FFT_N 1024
`define DECIMATE 20
`define RAW_SAMPLES `DECIMATE * `FFT_N
`define FIFO_DEPTH 65536
`define START_FLAG 8'b0101_1010  // 8'h5A
`define STOP_FLAG 8'b1010_0101   // 8'hA5

`include "fifo.v"
`include "ltc2292.v"
`include "ff_sync.v"
`include "adf4158.v"

module top (
`ifdef TOP_SIMULATE
   input wire clk80,
   input wire clk20,
`endif
   // =============== clocks, resets, LEDs, connectors ===============
   // 40MHz
   input wire                              clk_i,
   // General-purpose I/O.
   inout wire [`GPIO_WIDTH-1:0]            ext1_io,
   inout wire [`GPIO_WIDTH-1:0]            ext2_io,

   // ==================== FT2232H USB interface. ====================
   // FIFO data
   inout wire signed [`USB_DATA_WIDTH-1:0] ft_data_io,
   // Low when there is data in the buffer that can be read.
   input wire                              ft_rxf_n_i,
   // Low when there is room for transmission data in the FIFO.
   input wire                              ft_txe_n_i,
   // Drive low to load read data to ft_data_io each clock cycle.
   output wire                             ft_rd_n_o,
   // Drive low to write ft_data_io to FIFO for transmission.
   output reg                              ft_wr_n_o,
   // Flush transmission data to USB immediately.
   output wire                             ft_siwua_n_o,
   // 60MHz clock used to synchronize data transfers.
   input wire                              ft_clkout_i,
   // Drive low one period before ft_rd_n_o to signal read.
   output wire                             ft_oe_n_o,
   // Low when USB in suspend mode.
   input wire                              ft_suspend_n_i,

   // ============================== ADC =============================
   // Input data from ADC.
   input wire signed [`ADC_DATA_WIDTH-1:0] adc_d_i,
   // High value indicates overflow or underflow.
   input wire [1:0]                        adc_of_i,
   // LSB refers to channel A, MSB to channel B. Pulling OE and SHDN
   // low enables outputs.  E.g. 10 for each turns on channel A and
   // turns off channel B.
   output wire [1:0]                       adc_oe_o,
   output wire [1:0]                       adc_shdn_o,

   // ============================= mixer ============================
   // Low voltage enables mixer.
   output wire                             mix_enbl_n_o,

   // ======================== power amplifier =======================
   output wire                             pa_en_n_o,

   // ===================== frequency synthesizer ====================
   output wire                             adf_ce_o,
   output wire                             adf_le_o,
   output wire                             adf_clk_o,
   input wire                              adf_muxout_i,
   output wire                             adf_txdata_o,
   output wire                             adf_data_o
   // input wire                             adf_done_i,
);

   assign pa_en_n_o    = 1'b0;
   assign mix_enbl_n_o = 1'b1;
   assign adc_oe_o     = 2'b10;
   assign adc_shdn_o   = 2'b00;

`ifndef TOP_SIMULATE
   wire                            clk80;
   wire                            clk20;
   wire                            pll_lock;
   wire                            pll_fb;
   PLLE2_BASE #(
      .CLKFBOUT_MULT  (24 ),
      .DIVCLK_DIVIDE  (1  ),
      .CLKOUT0_DIVIDE (12 ),
      .CLKOUT1_DIVIDE (48 ),
      .CLKIN1_PERIOD  (25 )
   ) main_pll (
      .CLKOUT0  (clk80      ),
      .CLKOUT1  (clk20      ),
      .LOCKED   (pll_lock   ),
      .CLKIN1   (clk_i      ),
      .RST      (1'b0       ),
      .CLKFBOUT (pll_fb     ),
      .CLKFBIN  (pll_fb     )
   );
`endif

   wire                            adf_config_done;
   wire                            adf_ramp_start;
   wire                            adf_ramp_on;
   adf4158 adf4158 (
      .clk         (clk_i           ),
      .clk_20mhz   (clk20           ),
      .rst_n       (1'b1            ),
      .enable      (1'b1            ),
      .config_done (adf_config_done ),
      .le          (adf_le_o        ),
      .ce          (adf_ce_o        ),
      .muxout      (adf_muxout_i    ),
      .ramp_start  (adf_ramp_start  ),
      .ramp_on     (adf_ramp_on     ),
      .txdata      (adf_txdata_o    ),
      .data        (adf_data_o      )
   );

   reg                             lsb = 1'b1;
   wire [`ADC_DATA_WIDTH-1:0]      adc_chan_a;
   wire [`USB_DATA_WIDTH-1:0]      adc_chan_a_msb;
   wire [`USB_DATA_WIDTH-1:0]      adc_chan_a_lsb;
   wire [`ADC_DATA_WIDTH-1:0]      adc_chan_b;

   ltc2292 ltc2292 (
      .clk (clk_i      ),
      .di  (adc_d_i    ),
      .dao (adc_chan_a ),
      .dbo (adc_chan_b )
   );

   assign adc_chan_a_msb = {4'd0, adc_chan_a[`ADC_DATA_WIDTH-1:8]};
   assign adc_chan_a_lsb = adc_chan_a[7:0];

   wire [`USB_DATA_WIDTH-1:0]      adc_data = lsb ? adc_chan_a_lsb : adc_chan_a_msb;

   localparam NUM_STATES = 4;
   localparam CONFIG     = 0,
              IDLE       = 1,
              PROD       = 2,
              CONS       = 3;
   reg [NUM_STATES-1:0]            state = CONFIG,
                                   next  = CONFIG;
   wire [NUM_STATES-1:0]           state_ftclk_domain;
   reg                             cons_done = 1'b0;
   wire                            cons_done_clk80_domain;

   ff_sync #(
      .WIDTH  (1),
      .STAGES (2)
   ) cons_done_sync (
      .dest_clk (clk80                  ),
      .d        (cons_done              ),
      .q        (cons_done_clk80_domain )
   );

   ff_sync #(
      .WIDTH  (NUM_STATES ),
      .STAGES (2          )
   ) state_ftclk_sync (
      .dest_clk (ft_clkout_i        ),
      .d        (state              ),
      .q        (state_ftclk_domain )
   );

   // =============== Write clock (80MHz) state machine ==============
   localparam [$clog2(`RAW_SAMPLES)-1:0] RAW_SAMPLES_MAX = `RAW_SAMPLES-1;
   reg [$clog2(`RAW_SAMPLES)-1:0] raw_sample_ctr = `RAW_SAMPLES'd0;

   always @(posedge clk80) begin
      state <= next;
   end

   always @(*) begin
      next = {NUM_STATES{1'b0}};
      case (1'b1)
      state[CONFIG]:
        begin
           if (adf_config_done) next[IDLE] = 1'b1;
           else                 next[CONFIG] = 1'b1;
        end
      state[IDLE]:
        begin
           if (adf_ramp_start & lsb) next[PROD] = 1'b1;
           else                      next[IDLE] = 1'b1;
        end
      state[PROD]:
        begin
           if (raw_sample_ctr == RAW_SAMPLES_MAX & lsb) next[CONS] = 1'b1;
           else                                         next[PROD] = 1'b1;
        end
      state[CONS]:
        begin
           if (cons_done_clk80_domain) next[IDLE] = 1'b1;
           else                        next[CONS] = 1'b1;
        end
      default: next[IDLE] = 1'b1;
      endcase
   end

   always @(posedge clk80) begin
      raw_sample_ctr <= `RAW_SAMPLES'd0;
      lsb            <= ~lsb;
      case (1'b1)
      state[PROD]:
        begin
           if (lsb) raw_sample_ctr <= raw_sample_ctr + 1'b1;
           else     raw_sample_ctr <= raw_sample_ctr;
        end
      endcase

      fifo_wen <= 1'b0;
      case (1'b1)
      next[PROD]: fifo_wen <= 1'b1;
      endcase
   end
   // ================================================================

   wire                            fifo_full;
   wire                            fifo_almost_full;
   wire                            fifo_empty;
   wire                            fifo_almost_empty;
   reg                             fifo_ren = 1'b0;
   wire [`USB_DATA_WIDTH-1:0]      fifo_rdata;
   reg                             fifo_wen = 1'b0;
   fifo #(
      .WIDTH (`USB_DATA_WIDTH ),
      .DEPTH (`FIFO_DEPTH     )
   ) fifo (
      .wclk         (clk80             ),
      .rst_n        (1'b1              ),
      .wen          (fifo_wen          ),
      .full         (fifo_full         ),
      .almost_full  (fifo_almost_full  ),
      .wdata        (adc_data          ),
      .rclk         (ft_clkout_i       ),
      .ren          (fifo_ren          ),
      .empty        (fifo_empty        ),
      .almost_empty (fifo_almost_empty ),
      .rdata        (fifo_rdata        )
   );

   // ==================== FT clock state machine ====================
   localparam FTCLK_NUM_STATES = 7;
   localparam FTCLK_IDLE  = 0,
              FTCLK_START = 1,
              FTCLK_CONS  = 2,
              FTCLK_TXE   = 3,
              FTCLK_LAST  = 4,
              FTCLK_STOP  = 5,
              FTCLK_WAIT  = 6;
   reg [FTCLK_NUM_STATES-1:0] ftclk_state = FTCLK_IDLE,
                              ftclk_next = FTCLK_IDLE;

   always @(posedge ft_clkout_i) begin
      ftclk_state <= ftclk_next;
   end

   always @(*) begin
      ftclk_next = {FTCLK_NUM_STATES{1'b0}};
      case (1'b1)
      ftclk_state[FTCLK_IDLE]  : if (state_ftclk_domain[CONS] == 1'b1) ftclk_next[FTCLK_START] = 1'b1;
                                 else                                  ftclk_next[FTCLK_IDLE]  = 1'b1;
      ftclk_state[FTCLK_START] : if (~ft_txe_n_i)                      ftclk_next[FTCLK_CONS]  = 1'b1;
                                 else                                  ftclk_next[FTCLK_START] = 1'b1;
      ftclk_state[FTCLK_CONS]  : if (fifo_empty)                       ftclk_next[FTCLK_LAST]  = 1'b1;
                                 else if (ft_txe_n_i)                  ftclk_next[FTCLK_TXE]   = 1'b1;
                                 else                                  ftclk_next[FTCLK_CONS]  = 1'b1;
      ftclk_state[FTCLK_TXE]   : if (~ft_txe_n_i)                      ftclk_next[FTCLK_CONS]  = 1'b1;
                                 else                                  ftclk_next[FTCLK_TXE]   = 1'b1;
      ftclk_state[FTCLK_LAST]  : if (~ft_txe_n_i)                      ftclk_next[FTCLK_STOP]  = 1'b1;
                                 else                                  ftclk_next[FTCLK_LAST]  = 1'b1;
      ftclk_state[FTCLK_STOP]  : if (~ft_txe_n_i)                      ftclk_next[FTCLK_WAIT]  = 1'b1;
                                 else                                  ftclk_next[FTCLK_STOP]  = 1'b1;
      ftclk_state[FTCLK_WAIT]  : if (state_ftclk_domain[PROD] == 1'b1) ftclk_next[FTCLK_IDLE]  = 1'b1;
                                 else                                  ftclk_next[FTCLK_WAIT]  = 1'b1;
      default                  :                                       ftclk_next[FTCLK_IDLE]  = 1'b1;
      endcase
   end

   reg [`USB_DATA_WIDTH-1:0] ft_wr_data      = `USB_DATA_WIDTH'd0;
   reg [`USB_DATA_WIDTH-1:0] fifo_rdata_last = `USB_DATA_WIDTH'd0;
   reg                       ft_txe_last = 1'b0;
   always @(posedge ft_clkout_i) begin
      ft_wr_data <= `USB_DATA_WIDTH'd0;
      ft_wr_n_o       <= 1'b1;
      cons_done       <= 1'b0;
      ft_txe_last     <= ft_txe_n_i;

      case (1'b1)
      ftclk_next[FTCLK_START]:
        begin
           ft_wr_data <= `START_FLAG;
           ft_wr_n_o  <= 1'b0;
        end
      ftclk_next[FTCLK_CONS] & ftclk_state[FTCLK_TXE]:
        begin
           ft_wr_data <= fifo_rdata_last;
           ft_wr_n_o  <= 1'b0;
        end
      (ftclk_next[FTCLK_CONS] | ftclk_next[FTCLK_LAST]) & ~ftclk_state[FTCLK_TXE]:
        begin
           ft_wr_data <= fifo_rdata;
           ft_wr_n_o  <= 1'b0;
           fifo_rdata_last <= fifo_rdata;
        end
      ftclk_next[FTCLK_STOP]:
        begin
           ft_wr_data <= `STOP_FLAG;
           ft_wr_n_o  <= 1'b0;
           cons_done  <= 1'b1;
        end
      ftclk_next[FTCLK_WAIT]:
        begin
           ft_wr_n_o  <= 1'b1;
           cons_done  <= 1'b1;
        end
      endcase
   end

   always @(*) begin
      fifo_ren = 1'b0;
      case (1'b1)
      ftclk_next[FTCLK_START]: fifo_ren = 1'b1;
      ftclk_next[FTCLK_CONS] : fifo_ren = ~ft_txe_last;
      ftclk_next[FTCLK_STOP] : fifo_ren = 1'b0;
      endcase
   end
   // ================================================================

   assign ft_data_io = ft_oe_n_o ? ft_wr_data : `USB_DATA_WIDTH'dz;

   // leave configured for writes
   assign ft_oe_n_o    = 1'b1;
   assign ft_rd_n_o    = 1'b1;
   assign ft_siwua_n_o = 1'b1;

   assign ext1_io[0] = 1'b0;
   assign ext1_io[3] = state[0];
   assign ext1_io[1] = 1'b0;
   assign ext1_io[4] = state[1];
   assign ext1_io[2] = 1'b0;
   assign ext1_io[5] = state[2];

endmodule

`ifdef TOP_SIMULATE

module top_tb;

   reg clk20 = 1'b0;
   reg clk40 = 1'b0;
   reg clk60 = 1'b0;
   reg clk80 = 1'b0;

   reg muxout = 1'b0;

   localparam MUXOUT_ASSERT_CTR = 120000;
   reg [$clog2(MUXOUT_ASSERT_CTR)-1:0] muxout_ctr = 0;

   reg [`USB_DATA_WIDTH-1:0]           adc_ctr = 0;

   always @(posedge clk40) begin
      adc_ctr <= adc_ctr + 1'b1;
      if (muxout_ctr == MUXOUT_ASSERT_CTR) begin
         muxout_ctr <= 0;
         muxout     <= 1'b1;
      end else begin
         muxout_ctr <= muxout_ctr + 1;
         muxout     <= 1'b0;
      end
   end

   initial begin
      $dumpfile("tb/top_tb.vcd");
      $dumpvars(0, top_tb);

      #12.5;
      clk20 = ~clk20;
      forever clk20 = #25 ~clk20;
   end

   initial begin
      #12.5;
      clk80 = ~clk80;
      forever clk80 = #6.25 ~clk80;
   end

   initial begin
      #10000000 $finish;
   end

   reg ft_txe_n = 1'b0;
   integer ft_txe_on_ctr = 0;
   integer ft_txe_off_ctr = 0;
   always @(posedge clk60) begin
      if (ft_txe_n == 1'b0) begin
         ft_txe_off_ctr    <= 0;
         if (ft_txe_on_ctr == 500) begin
            ft_txe_n <= 1'b1;
         end else begin
            ft_txe_on_ctr <= ft_txe_on_ctr + 1;
         end
      end else begin
         ft_txe_on_ctr      <= 0;
         if (ft_txe_off_ctr == 5) begin
            ft_txe_n <= 1'b0;
         end else begin
            ft_txe_off_ctr <= ft_txe_off_ctr + 1;
         end
      end
   end

   always #12.5 clk40 = ~clk40;
   always #8.33 clk60 = ~clk60;

   wire [`USB_DATA_WIDTH-1:0] ft_data_io;
   top dut (
      .clk20          (clk20                   ),
      .clk80          (clk80                   ),
      .clk_i          (clk40                   ),
      .ft_data_io     (ft_data_io              ),
      .ft_rxf_n_i     (1'b1                    ),
      .ft_txe_n_i     (ft_txe_n                ),
      .ft_clkout_i    (clk60                   ),
      .ft_suspend_n_i (1'b1                    ),
      // send the least significant counter nibble with the full
      // counter to ensure corresponding most significant and least
      // significant bytes are sent in the correct order.
      .adc_d_i        ({adc_ctr[3:0], adc_ctr} ),
      .adc_of_i       (2'd0                    ),
      .adf_muxout_i   (muxout                  )
   );

   reg [`USB_DATA_WIDTH-1:0]  data_rx;
   always @(posedge clk60) begin
      if (~ft_txe_n & ~dut.ft_wr_n_o)
        data_rx <= ft_data_io;
      else
        data_rx <= `USB_DATA_WIDTH'dx;
   end

endmodule

`endif

`undef GPIO_WIDTH
`undef USB_DATA_WIDTH
`undef ADC_DATA_WIDTH
`undef SD_DATA_WIDTH
`undef FFT_N
`undef DECIMATE
`undef RAW_SAMPLES
`undef FIFO_DEPTH
`undef DELAY_BITS
`undef START_FLAG
`undef STOP_FLAG
