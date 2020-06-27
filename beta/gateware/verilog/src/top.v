`default_nettype none
`timescale 1ns/1ps

`define GPIO_WIDTH 6
`define USB_DATA_WIDTH 8
`define ADC_DATA_WIDTH 12
`define SD_DATA_WIDTH 4
`define FFT_N 1024
`define FIR_TAPS 120
`define DECIMATE 20
`define FIR_BANK_LEN `FIR_TAPS / `DECIMATE
`define RAW_SAMPLES `DECIMATE * `FFT_N
`define FT_FIFO_DEPTH 65536
`define START_FLAG 8'hFF
`define STOP_FLAG 8'h8F
`define FLAG_WIDTH 2

`include "fifo.v"
`include "ltc2292.v"
`include "ff_sync.v"
`include "adf4158.v"
`include "pll_sync_ctr.v"
`include "clk_enable.v"
`include "fir.v"
`include "window.v"
`include "fft.v"

module top #(
   parameter FIR_TAP_WIDTH     = 16,
   parameter FIR_NORM_SHIFT    = 2,
   parameter FIR_OUTPUT_WIDTH  = 15,
   parameter FFT_TWIDDLE_WIDTH = 10
) (
`ifdef TOP_SIMULATE
   input wire clk10,
   input wire clk20,
   input wire clk80,
   input wire clk120,
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
   output reg                              ft_rd_n_o,
   // Drive low to write ft_data_io to FIFO for transmission.
   output reg                              ft_wr_n_o,
   // Flush transmission data to USB immediately.
   output wire                             ft_siwua_n_o,
   // 60MHz clock used to synchronize data transfers.
   input wire                              ft_clkout_i,
   // Drive low one period before ft_rd_n_o to signal read.
   output reg                              ft_oe_n_o,
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

   localparam FFT_OUTPUT_WIDTH               = FIR_OUTPUT_WIDTH + 1 + $clog2(`FFT_N);
   localparam [$clog2(`FFT_N)-1:0] FFT_N_MAX = `FFT_N-1;

   // never flush tx/rx buffers
   assign ft_siwua_n_o = 1'b1;

   assign pa_en_n_o    = ~state[SAMPLE];
   assign mix_enbl_n_o = 1'b0;
   assign adc_oe_o     = 2'b00;
   assign adc_shdn_o   = 2'b00;

`ifndef TOP_SIMULATE
   wire                            clk80;
   wire                            clk20;
   wire                            clk10;
   wire                            clk120;
   wire                            pll_lock;
   wire                            pll_fb;
   PLLE2_BASE #(
      .CLKFBOUT_MULT  (24 ),
      .DIVCLK_DIVIDE  (1  ),
      .CLKOUT0_DIVIDE (12 ),
      .CLKOUT1_DIVIDE (48 ),
      .CLKOUT2_DIVIDE (96 ),
      .CLKOUT3_DIVIDE (8  ),
      .CLKIN1_PERIOD  (25 )
   ) main_pll (
      .CLKOUT0  (clk80      ),
      .CLKOUT1  (clk20      ),
      .CLKOUT2  (clk10      ),
      .CLKOUT3  (clk120     ),
      .LOCKED   (pll_lock   ),
      .CLKIN1   (clk_i      ),
      .RST      (1'b0       ),
      .CLKFBOUT (pll_fb     ),
      .CLKFBIN  (pll_fb     )
   );
`else
   reg                             pll_lock = 1'b1;
`endif

   // pll lock is asynchronous
   wire                            pll_lock_clk40;
   ff_sync #(
      .WIDTH  (1 ),
      .STAGES (2 )
   ) pll_lock_clk40_sync (
      .dest_clk (clk_i          ),
      .d        (pll_lock       ),
      .q        (pll_lock_clk40 )
   );

   wire                            clk80_40_phase_ctr;
   pll_sync_ctr #(
      .RATIO (2)
   ) pll_sync_ctr (
      .fst_clk (clk80              ),
      .slw_clk (clk_i              ),
      .ctr     (clk80_40_phase_ctr )
   );

   wire                            clk2_pos_en;
   clk_enable #(
      .DIVIDE (`DECIMATE)
   ) clk_enable (
      .clk_base (clk_i       ),
      .clk_en   (clk2_pos_en )
   );

   wire                            adf_config_done;
   wire                            adf_ramp_start;
   adf4158 adf4158 (
      .clk         (clk_i                             ),
      .clk20       (clk20                             ),
      .clk_o       (adf_clk_o                         ),
      .configure   (pll_lock_clk40 & ~adf_config_done ),
      .muxout      (adf_muxout_i                      ),
      .ramp_start  (adf_ramp_start                    ),
      .config_done (adf_config_done                   ),
      .le          (adf_le_o                          ),
      .ce          (adf_ce_o                          ),
      .txdata      (adf_txdata_o                      ),
      .data        (adf_data_o                        )
   );

   wire signed [`ADC_DATA_WIDTH-1:0] adc_chan_a;
   wire [`USB_DATA_WIDTH-1:0]        adc_single_chan_msb;
   wire [`USB_DATA_WIDTH-1:0]        adc_single_chan_lsb;
   wire signed [`ADC_DATA_WIDTH-1:0] adc_chan_b;

   ltc2292 ltc2292 (
      .clk (clk_i      ),
      .di  (adc_d_i    ),
      .dao (adc_chan_a ),
      .dbo (adc_chan_b )
   );
   wire signed [`ADC_DATA_WIDTH-1:0] adc_single_chan = adc_chan_b;

   assign adc_single_chan_msb = {4'd0, adc_single_chan[`ADC_DATA_WIDTH-1:8]};
   assign adc_single_chan_lsb = adc_single_chan[7:0];

   wire [`USB_DATA_WIDTH-1:0] ft_raw_data = clk80_40_phase_ctr ? adc_single_chan_lsb : adc_single_chan_msb;

   localparam NUM_OUTPUT = 4;
   localparam RAW    = 0,
              FIR    = 1,
              WINDOW = 2,
              FFT    = 3;
   reg [NUM_OUTPUT-1:0] out;
   initial begin
      out      = {NUM_OUTPUT{1'b0}};
      out[RAW] = 1'b1;
   end

   wire signed [FIR_OUTPUT_WIDTH-1:0] fir_out;
   wire                               fir_dvalid;
   fir #(
      .INPUT_WIDTH    (`ADC_DATA_WIDTH  ),
      .TAP_WIDTH      (FIR_TAP_WIDTH    ),
      .NORM_SHIFT     (FIR_NORM_SHIFT   ),
      .OUTPUT_WIDTH   (FIR_OUTPUT_WIDTH )
   ) fir (
      .clk        (clk_i           ),
      .en         (state[SAMPLE]   ),
      .clk_pos_en (clk2_pos_en     ),
      .din        (adc_single_chan ),
      .dout       (fir_out         ),
      .dvalid     (fir_dvalid      )
   );

   wire                        fir_fifo_empty;
   reg                         fir_fifo_ren = 1'b0;
   wire [FIR_OUTPUT_WIDTH-1:0] fir_fifo_rdata;
   wire                        fir_fifo_wen = fir_dvalid;
   fifo #(
      .WIDTH (FIR_OUTPUT_WIDTH ),
      .DEPTH (`FFT_N           )
   ) fir_fifo (
      .wclk         (clk_i                      ),
      .rst_n        (1'b1                       ),
      .wen          (fir_fifo_wen & clk2_pos_en ),
      .wdata        (fir_out                    ),
      .rclk         (clk_i                      ),
      .ren          (fir_fifo_ren               ),
      .empty        (fir_fifo_empty             ),
      .rdata        (fir_fifo_rdata             )
   );

   wire                               window_dvalid;
   wire signed [FIR_OUTPUT_WIDTH-1:0] window_out;
   window #(
      .N           (`FFT_N           ),
      .DATA_WIDTH  (FIR_OUTPUT_WIDTH ),
      .COEFF_WIDTH (FIR_TAP_WIDTH    )
   ) window (
      .clk    (clk_i          ),
      .en     (fir_dvalid     ),
      .clk_en (clk2_pos_en    ),
      .di     (fir_out        ),
      .dvalid (window_dvalid  ),
      .dout   (window_out     )
   );

   wire                            window_fifo_empty;
   wire                            window_fifo_full;
   reg                             window_fifo_ren = 1'b0;
   wire [FIR_OUTPUT_WIDTH-1:0]     window_fifo_rdata;
   wire                            window_fifo_wen = window_dvalid;
   fifo #(
      .WIDTH (FIR_OUTPUT_WIDTH ),
      .DEPTH (`FFT_N           )
   ) window_fifo (
      .wclk         (clk_i                         ),
      .rst_n        (1'b1                          ),
      .wen          (window_fifo_wen & clk2_pos_en ),
      .wdata        (window_out                    ),
      .rclk         (clk_i                         ),
      .ren          (window_fifo_ren               ),
      .empty        (window_fifo_empty             ),
      .full         (window_fifo_full              ),
      .rdata        (window_fifo_rdata             )
   );

   wire                               fft_valid;
   wire [$clog2(`FFT_N)-1:0]          fft_ctr;
   wire signed [FFT_OUTPUT_WIDTH-1:0] fft_re_o;
   wire signed [FFT_OUTPUT_WIDTH-1:0] fft_im_o;

   fft #(
      .N             (`FFT_N            ),
      .INPUT_WIDTH   (FIR_OUTPUT_WIDTH  ),
      .TWIDDLE_WIDTH (FFT_TWIDDLE_WIDTH ),
      .OUTPUT_WIDTH  (FFT_OUTPUT_WIDTH  )
   ) fft (
      .clk        (clk_i                    ),
      .clk_3x     (clk120                   ),
      .en         (state[PROC_FFT]          ),
      .valid      (fft_valid                ),
      .data_ctr_o (fft_ctr                  ),
      .data_re_i  (window_fifo_rdata        ),
      .data_im_i  ({FIR_OUTPUT_WIDTH{1'b0}} ),
      .data_re_o  (fft_re_o                 ),
      .data_im_o  (fft_im_o                 )
   );

   wire                            fft_fifo_empty;
   wire                            fft_fifo_full;
   reg                             fft_fifo_ren = 1'b0;
   wire [2*FFT_OUTPUT_WIDTH-1:0]   fft_fifo_rdata;
   fifo #(
      .WIDTH (2*FFT_OUTPUT_WIDTH ),
      .DEPTH (`FFT_N             )
   ) fft_fifo (
      .wclk         (clk_i                ),
      .rst_n        (1'b1                 ),
      .wen          (fft_valid            ),
      .wdata        ({fft_re_o, fft_im_o} ),
      .rclk         (clk10                ),
      .ren          (fft_fifo_ren         ),
      .empty        (fft_fifo_empty       ),
      .full         (fft_fifo_full        ),
      .rdata        (fft_fifo_rdata       )
   );

   // ============== System clock (40MHz) state machine ==============
   localparam NUM_STATES = 6;
   localparam CONFIG      = 0,
              IDLE        = 1,
              SAMPLE      = 2,
              PROC_FILTER = 3,  // filter and window
              PROC_FFT    = 4,
              TX          = 5;
   reg [NUM_STATES-1:0] state, next;
   initial begin
      state         = {NUM_STATES{1'b0}};
      state[CONFIG] = 1'b1;

      next         = {NUM_STATES{1'b0}};
      next[CONFIG] = 1'b1;
   end

   wire [NUM_STATES-1:0]           state_ftclk_domain;
   reg                             tx_done = 1'b0;
   wire                            tx_done_clk40_domain;

   ff_sync #(
      .WIDTH  (1),
      .STAGES (2)
   ) tx_done_sync (
      .dest_clk (clk_i                ),
      .d        (tx_done              ),
      .q        (tx_done_clk40_domain )
   );

   ff_sync #(
      .WIDTH  (NUM_STATES ),
      .STAGES (2          )
   ) state_ftclk_sync (
      .dest_clk (ft_clkout_i        ),
      .d        (state              ),
      .q        (state_ftclk_domain )
   );

   localparam [$clog2(`RAW_SAMPLES)-1:0] RAW_SAMPLES_MAX = `RAW_SAMPLES-1;
   reg [$clog2(`RAW_SAMPLES)-1:0] raw_sample_ctr = `RAW_SAMPLES'd0;

   always @(posedge clk_i) begin
      state <= next;
   end

   always @(*) begin
      next = {NUM_STATES{1'b0}};
      case (1'b1)
      state[CONFIG]:
        begin
           if (adf_config_done) next[IDLE]   = 1'b1;
           else                 next[CONFIG] = 1'b1;
        end
      state[IDLE]:
        begin
           if (adf_ramp_start) next[SAMPLE] = 1'b1;
           else                next[IDLE]   = 1'b1;
        end
      state[SAMPLE]:
        begin
           if (raw_sample_ctr == RAW_SAMPLES_MAX) next[PROC_FILTER] = 1'b1;
           else                                   next[SAMPLE]      = 1'b1;
        end
      state[PROC_FILTER]:
        begin
           if (window_fifo_full) next[PROC_FFT]    = 1'b1;
           else                  next[PROC_FILTER] = 1'b1;
        end
      state[PROC_FFT]:
        begin
           if (fft_fifo_full) next[TX]       = 1'b1;
           else               next[PROC_FFT] = 1'b1;
        end
      state[TX]:
        begin
           if (tx_done_clk40_domain) next[IDLE] = 1'b1;
           else                      next[TX]   = 1'b1;
        end
      default: next[IDLE] = 1'b1;
      endcase
   end

   always @(posedge clk_i) begin
      raw_sample_ctr <= `RAW_SAMPLES'd0;
      case (1'b1)
      state[SAMPLE] : raw_sample_ctr <= raw_sample_ctr + 1'b1;
      endcase

      ft_fifo_wen     <= 1'b0;
      window_fifo_ren <= 1'b0;
      case (1'b1)
      next[SAMPLE]   : ft_fifo_wen     <= 1'b1;
      next[PROC_FFT] : window_fifo_ren <= 1'b1;
      endcase
   end
   // ================================================================

   wire                            ft_fifo_empty;
   reg                             ft_fifo_ren = 1'b0;
   wire [`USB_DATA_WIDTH-1:0]      ft_fifo_rdata;
   reg                             ft_fifo_wen = 1'b0;
   fifo #(
      .WIDTH (`USB_DATA_WIDTH ),
      .DEPTH (`FT_FIFO_DEPTH  )
   ) ft_fifo (
      .wclk         (clk80         ),
      .rst_n        (1'b1          ),
      .wen          (ft_fifo_wen   ),
      .wdata        (ft_raw_data   ),
      .rclk         (ft_clkout_i   ),
      .ren          (ft_fifo_ren   ),
      .empty        (ft_fifo_empty ),
      .rdata        (ft_fifo_rdata )
   );

   // ==================== FT clock state machine ====================
   localparam FTCLK_NUM_STATES = 8;
   localparam FTCLK_IDLE  = 0,
              FTCLK_START = 1,
              FTCLK_TX    = 2,
              FTCLK_TXE   = 3,
              FTCLK_LAST  = 4,
              FTCLK_STOP  = 5,
              FTCLK_WAIT  = 6,
              FTCLK_READ  = 7;
   reg [FTCLK_NUM_STATES-1:0] ftclk_state, ftclk_next;
   initial begin
      ftclk_state             = {FTCLK_NUM_STATES{1'b0}};
      ftclk_state[FTCLK_IDLE] = 1'b1;

      ftclk_next             = {FTCLK_NUM_STATES{1'b0}};
      ftclk_next[FTCLK_IDLE] = 1'b1;
   end

   always @(posedge ft_clkout_i) begin
      ftclk_state <= ftclk_next;
   end

   always @(*) begin
      ftclk_next = {FTCLK_NUM_STATES{1'b0}};
      case (1'b1)
      ftclk_state[FTCLK_IDLE]  : if (state_ftclk_domain[TX])     ftclk_next[FTCLK_START] = 1'b1;
                                 else                            ftclk_next[FTCLK_IDLE]  = 1'b1;
      ftclk_state[FTCLK_START] : if (flag_ctr == max_flag_ctr)   ftclk_next[FTCLK_TX]    = 1'b1;
                                 else                            ftclk_next[FTCLK_START] = 1'b1;
      ftclk_state[FTCLK_TX]    : if (ft_fifo_empty)              ftclk_next[FTCLK_LAST]  = 1'b1;
                                 else if (ft_txe_n_i)            ftclk_next[FTCLK_TXE]   = 1'b1;
                                 else                            ftclk_next[FTCLK_TX]    = 1'b1;
      ftclk_state[FTCLK_TXE]   : if (~ft_txe_n_i)                ftclk_next[FTCLK_TX]    = 1'b1;
                                 else                            ftclk_next[FTCLK_TXE]   = 1'b1;
      ftclk_state[FTCLK_LAST]  : if (~ft_txe_n_i)                ftclk_next[FTCLK_STOP]  = 1'b1;
                                 else                            ftclk_next[FTCLK_LAST]  = 1'b1;
      ftclk_state[FTCLK_STOP]  : if (flag_ctr == max_flag_ctr)   ftclk_next[FTCLK_WAIT]  = 1'b1;
                                 else                            ftclk_next[FTCLK_STOP]  = 1'b1;
      ftclk_state[FTCLK_WAIT]  : if (state_ftclk_domain[SAMPLE]) ftclk_next[FTCLK_IDLE]  = 1'b1;
                                 else                            ftclk_next[FTCLK_WAIT]  = 1'b1;
      default                  :                                 ftclk_next[FTCLK_IDLE]  = 1'b1;
      endcase
   end

   reg [`USB_DATA_WIDTH-1:0] ft_wr_data         = `USB_DATA_WIDTH'd0;
   reg [`USB_DATA_WIDTH-1:0] ft_fifo_rdata_last = `USB_DATA_WIDTH'd0;
   reg                       ft_txe_last        = 1'b0;
   reg [`FLAG_WIDTH-1:0]     flag_ctr           = `FLAG_WIDTH'd0;
   reg [`FLAG_WIDTH-1:0]     max_flag_ctr       = `FLAG_WIDTH'd2;
   always @(posedge ft_clkout_i) begin
      ft_wr_data  <= `USB_DATA_WIDTH'd0;
      ft_wr_n_o   <= 1'b1;
      tx_done     <= 1'b0;
      ft_txe_last <= ft_txe_n_i;
      flag_ctr    <= `FLAG_WIDTH'd0;
      ft_oe_n_o   <= 1'b1;
      ft_rd_n_o   <= 1'b1;

      case (1'b1)
      ftclk_next[FTCLK_START]:
        begin
           ft_wr_data <= `START_FLAG;
           ft_wr_n_o  <= 1'b0;
           if (~ft_txe_n_i) flag_ctr <= flag_ctr + 1'b1;
        end
      ftclk_next[FTCLK_TX] & ftclk_state[FTCLK_TXE]:
        begin
           ft_wr_data <= ft_fifo_rdata_last;
           ft_wr_n_o  <= 1'b0;
        end
      (ftclk_next[FTCLK_TX] | ftclk_next[FTCLK_LAST]) & ~ftclk_state[FTCLK_TXE]:
        begin
           ft_wr_data         <= ft_fifo_rdata;
           ft_wr_n_o          <= 1'b0;
           ft_fifo_rdata_last <= ft_fifo_rdata;
        end
      ftclk_next[FTCLK_STOP]:
        begin
           ft_wr_data <= `STOP_FLAG;
           ft_wr_n_o  <= 1'b0;
           tx_done    <= 1'b1;
           if (~ft_txe_n_i) flag_ctr <= flag_ctr + 1'b1;
        end
      ftclk_next[FTCLK_WAIT]:
        begin
           ft_wr_n_o <= 1'b1;
           tx_done   <= 1'b1;
        end
      ftclk_next[FTCLK_READ]:
        begin
           ft_oe_n_o <= 1'b0;
           if (~ft_oe_n_o) ft_rd_n_o <= 1'b0;
        end
      endcase
   end

   always @(*) begin
      ft_fifo_ren = 1'b0;
      case (1'b1)
      ftclk_next[FTCLK_START] & (flag_ctr + 1'b1 == max_flag_ctr) : ft_fifo_ren = ~ft_txe_last;
      ftclk_next[FTCLK_TX]                                        : ft_fifo_ren = ~ft_txe_last;
      ftclk_next[FTCLK_STOP]                                      : ft_fifo_ren = 1'b0;
      endcase
   end
   // ================================================================

   assign ft_data_io = ft_oe_n_o ? ft_wr_data : `USB_DATA_WIDTH'dz;

   assign ext1_io[0] = 1'b0;
   assign ext1_io[3] = state[SAMPLE];
   assign ext1_io[1] = 1'b0;
   assign ext1_io[4] = state[TX];
   assign ext1_io[2] = 1'b0;
   assign ext1_io[5] = clk_i;

   assign ext2_io[0] = 1'b0;
   assign ext2_io[3] = ftclk_state[FTCLK_TX];
   assign ext2_io[1] = 1'b0;
   assign ext2_io[4] = ftclk_state[FTCLK_WAIT];
   assign ext2_io[2] = 1'b0;
   assign ext2_io[5] = adf_muxout_i;

endmodule

`ifdef TOP_SIMULATE

module top_tb;

   reg clk10  = 1'b0;
   reg clk20  = 1'b0;
   reg clk40  = 1'b0;
   reg clk60  = 1'b0;
   reg clk80  = 1'b0;
   reg clk120 = 1'b0;

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
      #12.5;
      clk10 = ~clk10;
      forever clk10 = #50 ~clk10;
   end

   initial begin
      #12.5;
      clk120 = ~clk120;
      forever clk120 = #4.167 ~clk120;
   end

   initial begin
      #10000000 $finish;
   end

   reg ft_txe_n = 1'b0;
   integer ft_txe_on_ctr = 0;
   integer ft_txe_off_ctr = 0;
   // Note: uncomment if you want to test effect of ft_txe_n.
   // always @(posedge clk60) begin
   //    if (ft_txe_n == 1'b0) begin
   //       ft_txe_off_ctr    <= 0;
   //       if (ft_txe_on_ctr == 500) begin
   //          ft_txe_n <= 1'b1;
   //       end else begin
   //          ft_txe_on_ctr <= ft_txe_on_ctr + 1;
   //       end
   //    end else begin
   //       ft_txe_on_ctr      <= 0;
   //       if (ft_txe_off_ctr == 5) begin
   //          ft_txe_n <= 1'b0;
   //       end else begin
   //          ft_txe_off_ctr <= ft_txe_off_ctr + 1;
   //       end
   //    end
   // end

   always #12.5 clk40 = ~clk40;
   always #8.33 clk60 = ~clk60;

   wire [`USB_DATA_WIDTH-1:0] ft_data_io;
   top #(
      .FIR_TAP_WIDTH     (16 ),
      .FIR_NORM_SHIFT    (4  ),
      .FIR_OUTPUT_WIDTH  (13 ),
      .FFT_TWIDDLE_WIDTH (10 )
   ) dut (
      .clk10          (clk10                   ),
      .clk20          (clk20                   ),
      .clk80          (clk80                   ),
      .clk120         (clk120                  ),
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
`undef FIR_TAPS
`undef DECIMATE
`undef FIR_BANK_LEN
`undef RAW_SAMPLES
`undef FT_FIFO_DEPTH
`undef DELAY_BITS
`undef START_FLAG
`undef STOP_FLAG
`undef FLAG_WIDTH
