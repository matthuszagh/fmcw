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

module top (
`ifdef TOP_SIMULATE
   input wire clk80,
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

   assign pa_en_n_o = 1'b1;
   assign mix_enbl_n_o = 1'b1;
   // assign adc_oe_o = 2'b10;
   // assign adc_shdn_o = 2'b00;
   assign adc_oe_o = 2'b11;
   assign adc_shdn_o = 2'b11;

`ifndef TOP_SIMULATE
   wire                            clk80;
   wire                            pll_lock;
   wire                            pll_fb;
   PLLE2_BASE #(
      .CLKFBOUT_MULT  (24 ),
      .DIVCLK_DIVIDE  (1  ),
      .CLKOUT0_DIVIDE (12 ),
      .CLKIN1_PERIOD  (25 )
   ) main_pll (
      .CLKOUT0  (clk80      ),
      .LOCKED   (pll_lock   ),
      .CLKIN1   (clk_i      ),
      .RST      (1'b0       ),
      .CLKFBOUT (pll_fb     ),
      .CLKFBIN  (pll_fb     )
   );
`endif

   reg                             lsb = 1'b0;
   wire [`ADC_DATA_WIDTH-1:0]      adc_chan_a;
   wire [`ADC_DATA_WIDTH-1:0]      adc_chan_a_msb;
   wire [`ADC_DATA_WIDTH-1:0]      adc_chan_a_lsb;
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

   //
   localparam [0:0] PROD_STATE = 2'b0;
   localparam [0:0] CONS_STATE = 2'b1;
   reg                             lock = PROD_STATE;
   wire                            lock_ftclk_domain;
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
      .WIDTH  (1),
      .STAGES (2)
   ) lock_ftclk_sync (
      .dest_clk (ft_clkout_i       ),
      .d        (lock              ),
      .q        (lock_ftclk_domain )
   );

   localparam [$clog2(`RAW_SAMPLES)-1:0] RAW_SAMPLES_MAX = `RAW_SAMPLES-1;
   reg [$clog2(`RAW_SAMPLES)-1:0] raw_sample_ctr = `RAW_SAMPLES'd0;
   always @(posedge clk80) begin
      if (lock == PROD_STATE) begin
         if (raw_sample_ctr == RAW_SAMPLES_MAX & lsb) begin
            lock           <= CONS_STATE;
            raw_sample_ctr <= `RAW_SAMPLES'd0;
            lsb            <= 1'b0;
         end else begin
            if (lsb)
              raw_sample_ctr <= raw_sample_ctr + 1'b1;
            lsb <= ~lsb;
         end
      end else begin
         if (cons_done_clk80_domain) begin
            lock           <= PROD_STATE;
            raw_sample_ctr <= `RAW_SAMPLES'd0;
            lsb            <= 1'b0;
         end
      end
   end

   always @(*) begin
      case (lock)
      PROD_STATE:
        begin
           fifo_wen = 1'b1;
        end
      CONS_STATE:
        begin
           fifo_wen = 1'b0;
        end
      endcase
   end

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

   reg                             lock_ftclk_domain_last = PROD_STATE;
   reg                             send_start = 1'b0;
   reg                             send_stop  = 1'b0;
   reg                             wait_sync = 1'b0;
   always @(posedge ft_clkout_i) begin
      if (!ft_txe_n_i) begin
         lock_ftclk_domain_last <= lock_ftclk_domain;
      end

      if (lock_ftclk_domain == CONS_STATE & ~cons_done & ~wait_sync) begin
         if (fifo_empty) begin
            cons_done <= 1'b1;
         end
      end else if (cons_done && !ft_txe_n_i) begin
         wait_sync <= 1'b1;
         cons_done <= 1'b0;
      end else if (lock_ftclk_domain == PROD_STATE) begin
         cons_done <= 1'b0;
         wait_sync <= 1'b0;
      end
   end

   reg [`USB_DATA_WIDTH-1:0] ft_wr_data;
   always @(*) begin
      case (lock_ftclk_domain)
      PROD_STATE:
        begin
           ft_wr_data = `USB_DATA_WIDTH'd0;
           ft_wr_n_o  = 1'b1;
           fifo_ren   = 1'b0;
        end
      CONS_STATE:
        begin
           if (lock_ftclk_domain_last == PROD_STATE) begin
              ft_wr_data = `START_FLAG;
              ft_wr_n_o  = ft_txe_n_i;
              fifo_ren   = 1'b1;
           end else if (cons_done) begin
              ft_wr_data = `STOP_FLAG;
              ft_wr_n_o  = ft_txe_n_i;
              fifo_ren   = 1'b0;
           end else if (wait_sync) begin
              ft_wr_data = `USB_DATA_WIDTH'd0;
              ft_wr_n_o  = 1'b1;
              fifo_ren   = 1'b0;
           end else begin
              ft_wr_data = fifo_rdata;
              ft_wr_n_o  = ~(~ft_txe_n_i && fifo_ren);
              fifo_ren   = ~ft_txe_n_i && ~fifo_empty;
           end
        end
      endcase
   end

   assign ft_data_io = ft_oe_n_o ? ft_wr_data : `USB_DATA_WIDTH'dz;

   // leave configured for writes
   assign ft_oe_n_o    = 1'b1;
   assign ft_rd_n_o    = 1'b1;
   assign ft_siwua_n_o = 1'b1;

   assign ext1_io[0] = 1'b0;
   assign ext1_io[3] = lock;
   assign ext1_io[1] = 1'b0;
   assign ext1_io[4] = fifo_almost_empty;

endmodule

`ifdef TOP_SIMULATE

module top_tb;

   reg clk40 = 1'b0;
   reg clk60 = 1'b0;
   reg clk80 = 1'b0;

   initial begin
      $dumpfile("tb/top_tb.vcd");
      $dumpvars(0, top_tb);

      #10000000 $finish;
   end

   always #12.5 clk40 = ~clk40;
   always #6.25 clk80 = ~clk80;
   always #8.33 clk60 = ~clk60;

   wire [`USB_DATA_WIDTH-1:0] ft_data_io;
   top dut (
      .clk80          (clk80      ),
      .clk_i          (clk40      ),
      .ft_data_io     (ft_data_io ),
      .ft_rxf_n_i     (1'b1       ),
      .ft_txe_n_i     (1'b0       ),
      .ft_clkout_i    (clk60      ),
      .ft_suspend_n_i (1'b1       ),
      .adc_d_i        (12'hfff    ),
      .adc_of_i       (2'd0       )
      // .adf_muxout_i,
   );

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
