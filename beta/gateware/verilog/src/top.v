`default_nettype none
`timescale 1ns/1ps

`define GPIO_WIDTH 6
`define USB_DATA_WIDTH 8
`define ADC_DATA_WIDTH 12
`define SD_DATA_WIDTH 4

`include "async_fifo.v"
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

   localparam FFT_N            = 1024;
   localparam DECIMATE         = 20;
   localparam RAW_SAMPLES      = DECIMATE * FFT_N;
   localparam FT_FIFO_DEPTH    = 65536;
   localparam START_FLAG       = 8'hFF;
   localparam STOP_FLAG        = 8'h8F;
   localparam FFT_OUTPUT_WIDTH = FIR_OUTPUT_WIDTH + 1 + $clog2(FFT_N);

   // never flush tx/rx buffers
   assign ft_siwua_n_o = 1'b1;

   assign pa_en_n_o    = ~state[SAMPLE];
   assign mix_enbl_n_o = 1'b0;
   assign adc_oe_o     = 2'b00;
   assign adc_shdn_o   = 2'b00;

`ifndef TOP_SIMULATE
   wire clk80;
   wire clk20;
   wire clk10;
   wire clk120;
   wire pll_lock;
   wire pll_fb;
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
   reg pll_lock = 1'b1;
`endif

   // pll lock is asynchronous
   wire pll_lock_clk40;
   ff_sync #(
      .WIDTH  (1 ),
      .STAGES (2 )
   ) pll_lock_clk40_sync (
      .dest_clk (clk_i          ),
      .d        (pll_lock       ),
      .q        (pll_lock_clk40 )
   );

   wire clk80_40_phase_ctr;
   pll_sync_ctr #(
      .RATIO (2)
   ) clk80_40_sync_ctr (
      .fst_clk (clk80              ),
      .slw_clk (clk_i              ),
      .ctr     (clk80_40_phase_ctr )
   );

   wire [2:0] clk80_10_phase_ctr;
   pll_sync_ctr #(
      .RATIO (8)
   ) clk80_10_sync_ctr (
      .fst_clk (clk80              ),
      .slw_clk (clk10              ),
      .ctr     (clk80_10_phase_ctr )
   );

   wire clk2_pos_en;
   clk_enable #(
      .DIVIDE (DECIMATE)
   ) clk_enable (
      .clk_base (clk_i       ),
      .clk_en   (clk2_pos_en )
   );

   reg start_ftclk = 1'b0;
   reg stop_ftclk  = 1'b0;
   wire start, stop;
   ff_sync #(
      .WIDTH  (1 ),
      .STAGES (2 )
   ) start_sync (
      .dest_clk (clk_i       ),
      .d        (start_ftclk ),
      .q        (start       )
   );
   ff_sync #(
      .WIDTH  (1 ),
      .STAGES (2 )
   ) stop_sync (
      .dest_clk (clk_i      ),
      .d        (stop_ftclk ),
      .q        (stop       )
   );

   reg         adf_reg_fifo_wen;
   reg         adf_reg_fifo_ren;
   wire        adf_reg_fifo_empty;
   reg [2:0]   adf_reg;
   reg [31:0]  adf_val;
   wire [2:0]  adf_reg_sysclk;
   wire [31:0] adf_val_sysclk;
   async_fifo #(
      .WIDTH (35 ),
      .DEPTH (8  )
   ) adf_reg_fifo (
      .wclk         (ft_clkout_i                      ),
      .rst_n        (~stop_ftclk                      ),
      .wen          (adf_reg_fifo_wen                 ),
      .wdata        ({adf_reg, adf_val}               ),
      .rclk         (clk_i                            ),
      .ren          (adf_reg_fifo_ren                 ),
      .empty        (adf_reg_fifo_empty               ),
      .rdata        ({adf_reg_sysclk, adf_val_sysclk} )
   );
   always @(posedge clk_i) begin
      if (~adf_reg_fifo_empty) adf_reg_fifo_ren <= 1'b1;
      else                     adf_reg_fifo_ren <= 1'b0;
   end

   wire                            adf_active;
   wire                            adf_ramp_start;
   adf4158 adf4158 (
      .clk         (clk_i            ),
      .clk20       (clk20            ),
      .arst_n      (~stop_ftclk      ),
      .clk_o       (adf_clk_o        ),
      .configure   (start            ),
      .muxout      (adf_muxout_i     ),
      .reg_num     (adf_reg_sysclk   ),
      .load_reg    (adf_reg_fifo_ren ),
      .reg_val     (adf_val_sysclk   ),
      .ramp_start  (adf_ramp_start   ),
      .active      (adf_active       ),
      .le          (adf_le_o         ),
      .ce          (adf_ce_o         ),
      .txdata      (adf_txdata_o     ),
      .data        (adf_data_o       )
   );

   wire signed [`ADC_DATA_WIDTH-1:0] adc_chan_a;
   wire [`USB_DATA_WIDTH-1:0]        adc_single_chan_msb;
   wire [`USB_DATA_WIDTH-1:0]        adc_single_chan_lsb;
   wire signed [`ADC_DATA_WIDTH-1:0] adc_chan_b;

   wire                              use_chan_a;
   reg                               use_chan_a_ftclk = 1'b1;
   ff_sync #(
      .WIDTH  (1),
      .STAGES (2)
   ) chan_a_sync (
      .dest_clk (clk_i            ),
      .d        (use_chan_a_ftclk ),
      .q        (use_chan_a       )
   );

   wire                              use_chan_b;
   reg                               use_chan_b_ftclk = 1'b0;
   ff_sync #(
      .WIDTH  (1),
      .STAGES (2)
   ) chan_b_sync (
      .dest_clk (clk_i            ),
      .d        (use_chan_b_ftclk ),
      .q        (use_chan_b       )
   );

   ltc2292 ltc2292 (
      .clk (clk_i      ),
      .di  (adc_d_i    ),
      .dao (adc_chan_a ),
      .dbo (adc_chan_b )
   );
   wire signed [`ADC_DATA_WIDTH-1:0] adc_single_chan = use_chan_a ? adc_chan_a : adc_chan_b;

   assign adc_single_chan_msb = {4'd0, adc_single_chan[`ADC_DATA_WIDTH-1:8]};
   assign adc_single_chan_lsb = adc_single_chan[7:0];

   wire [`USB_DATA_WIDTH-1:0] ft_raw_data = clk80_40_phase_ctr ? adc_single_chan_lsb : adc_single_chan_msb;

   localparam RAW    = 2'd0,
              FIR    = 2'd1,
              WINDOW = 2'd2,
              FFT    = 2'd3;
   reg [1:0]  out_ftclk = RAW;
   wire [1:0] out;
   ff_sync #(
      .WIDTH  (2),
      .STAGES (2)
   ) out_sync (
      .dest_clk (clk_i     ),
      .d        (out_ftclk ),
      .q        (out       )
   );

   wire signed [FIR_OUTPUT_WIDTH-1:0] fir_out;
   wire                               fir_dvalid;
   fir #(
      .INPUT_WIDTH    (`ADC_DATA_WIDTH  ),
      .TAP_WIDTH      (FIR_TAP_WIDTH    ),
      .NORM_SHIFT     (FIR_NORM_SHIFT   ),
      .OUTPUT_WIDTH   (FIR_OUTPUT_WIDTH )
   ) fir (
      .clk        (clk_i           ),
      .arst_n     (~stop_ftclk     ),
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
   async_fifo #(
      .WIDTH (FIR_OUTPUT_WIDTH ),
      .DEPTH (FFT_N            )
   ) fir_fifo (
      .wclk         (clk_i                      ),
      .rst_n        (~stop_ftclk                ),
      .wen          (fir_fifo_wen & clk2_pos_en ),
      .wdata        (fir_out                    ),
      .rclk         (clk_i                      ),
      .ren          (fir_fifo_ren               ),
      .empty        (fir_fifo_empty             ),
      .rdata        (fir_fifo_rdata             )
   );

   localparam FIR_REM_WIDTH = 16 - FIR_OUTPUT_WIDTH;
   reg [`USB_DATA_WIDTH-1:0]       ft_fir_fifo_data;
   always @(*) begin
      case (clk80_40_phase_ctr)
      1'b0: ft_fir_fifo_data = {{FIR_REM_WIDTH{1'b0}}, fir_fifo_rdata[FIR_OUTPUT_WIDTH-1:8]};
      1'b1: ft_fir_fifo_data = fir_fifo_rdata[7:0];
      endcase
   end

   wire                               window_dvalid;
   wire signed [FIR_OUTPUT_WIDTH-1:0] window_out;
   window #(
      .N           (FFT_N            ),
      .DATA_WIDTH  (FIR_OUTPUT_WIDTH ),
      .COEFF_WIDTH (FIR_TAP_WIDTH    )
   ) window (
      .clk    (clk_i          ),
      .arst_n (~stop_ftclk    ),
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
   // TODO: use a synchronous fifo
   async_fifo #(
      .WIDTH (FIR_OUTPUT_WIDTH ),
      .DEPTH (FFT_N            )
   ) window_fifo (
      .wclk         (clk_i                         ),
      .rst_n        (~stop_ftclk                   ),
      .wen          (window_fifo_wen & clk2_pos_en ),
      .wdata        (window_out                    ),
      .rclk         (clk_i                         ),
      .ren          (window_fifo_ren               ),
      .empty        (window_fifo_empty             ),
      .full         (window_fifo_full              ),
      .rdata        (window_fifo_rdata             )
   );

   reg [`USB_DATA_WIDTH-1:0]       ft_window_fifo_data;
   always @(*) begin
      case (clk80_40_phase_ctr)
      1'b0: ft_window_fifo_data = {{FIR_REM_WIDTH{1'b0}}, window_fifo_rdata[FIR_OUTPUT_WIDTH-1:8]};
      1'b1: ft_window_fifo_data = window_fifo_rdata[7:0];
      endcase
   end

   wire                               fft_valid;
   wire [$clog2(FFT_N)-1:0]           fft_ctr;
   wire signed [FFT_OUTPUT_WIDTH-1:0] fft_re_o;
   wire signed [FFT_OUTPUT_WIDTH-1:0] fft_im_o;

   fft #(
      .N             (FFT_N             ),
      .INPUT_WIDTH   (FIR_OUTPUT_WIDTH  ),
      .TWIDDLE_WIDTH (FFT_TWIDDLE_WIDTH ),
      .OUTPUT_WIDTH  (FFT_OUTPUT_WIDTH  )
   ) fft (
      .clk        (clk_i                    ),
      .clk_3x     (clk120                   ),
      .arst_n     (~stop_ftclk              ),
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
   async_fifo #(
      .WIDTH (2*FFT_OUTPUT_WIDTH ),
      .DEPTH (FFT_N              )
   ) fft_fifo (
      .wclk         (clk_i                ),
      .rst_n        (~stop_ftclk          ),
      .wen          (fft_valid            ),
      .wdata        ({fft_re_o, fft_im_o} ),
      .rclk         (clk10                ),
      .ren          (fft_fifo_ren         ),
      .empty        (fft_fifo_empty       ),
      .full         (fft_fifo_full        ),
      .rdata        (fft_fifo_rdata       )
   );

   // TODO this is not properly parameterized. Currently, we assume
   // FIR_OUTPUT_WIDTH = 13, which gives FFT_OUTPUT_WIDTH = 24.
   // localparam FFT_REM_WIDTH = 64 - (2 * FFT_OUTPUT_WIDTH);
   reg [`USB_DATA_WIDTH-1:0] ft_fft_fifo_data;
   always @(*) begin
      case (clk80_10_phase_ctr)
      3'd0: ft_fft_fifo_data = 8'd0;
      3'd1: ft_fft_fifo_data = 8'd0;
      3'd2: ft_fft_fifo_data = fft_fifo_rdata[47:40];
      3'd3: ft_fft_fifo_data = fft_fifo_rdata[39:32];
      3'd4: ft_fft_fifo_data = fft_fifo_rdata[31:24];
      3'd5: ft_fft_fifo_data = fft_fifo_rdata[23:16];
      3'd6: ft_fft_fifo_data = fft_fifo_rdata[15:8];
      3'd7: ft_fft_fifo_data = fft_fifo_rdata[7:0];
      endcase
   end

   // ============== System clock (40MHz) state machine ==============
   localparam NUM_STATES = 7;
   localparam IDLE        = 0,
              CONFIG      = 1,
              WAIT        = 2,
              SAMPLE      = 3,
              PROC_FILTER = 4,  // filter and window
              PROC_FFT    = 5,
              TX          = 6;
   reg [NUM_STATES-1:0] state, next;
   initial begin
      state         = {NUM_STATES{1'b0}};
      state[IDLE]   = 1'b1;

      next         = {NUM_STATES{1'b0}};
      next[IDLE]   = 1'b1;
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

   localparam [$clog2(RAW_SAMPLES)-1:0] RAW_SAMPLES_MAX = RAW_SAMPLES-1;
   reg [$clog2(RAW_SAMPLES)-1:0] raw_sample_ctr = {RAW_SAMPLES{1'b0}};

   always @(posedge clk_i) begin
      state <= next;
   end

   always @(*) begin
      next = {NUM_STATES{1'b0}};
      case (1'b1)
      state[IDLE]:
        begin
           if (start) next[CONFIG] = 1'b1;
           else       next[IDLE]   = 1'b1;
        end
      state[CONFIG]:
        begin
           if (adf_active) next[WAIT]   = 1'b1;
           else            next[CONFIG] = 1'b1;
        end
      state[WAIT]:
        begin
           if (adf_ramp_start) next[SAMPLE] = 1'b1;
           else                next[WAIT]   = 1'b1;
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
           if (stop)                      next[IDLE] = 1'b1;
           else if (tx_done_clk40_domain) next[WAIT] = 1'b1;
           else                           next[TX]   = 1'b1;
        end
      default: next[IDLE] = 1'b1;
      endcase
   end

   always @(posedge clk_i) begin
      raw_sample_ctr <= {RAW_SAMPLES{1'b0}};
      case (1'b1)
      state[SAMPLE] : raw_sample_ctr <= raw_sample_ctr + 1'b1;
      endcase

      ft_fifo_wen     <= 1'b0;
      window_fifo_ren <= 1'b0;
      case (1'b1)
      next[SAMPLE]   : if (out == RAW) ft_fifo_wen     <= 1'b1;
                       else            ft_fifo_wen     <= 1'b0;
      next[PROC_FFT] :                 window_fifo_ren <= 1'b1;
      next[TX]       :
        begin
           if (out == RAW) ft_fifo_wen <= 1'b0;
           else begin
              ft_fifo_wen     <= 1'b1;
              fir_fifo_ren    <= 1'b0;
              window_fifo_ren <= 1'b0;
              fft_fifo_ren    <= 1'b0;
              case (out)
              FIR    : fir_fifo_ren    <= 1'b1;
              WINDOW : window_fifo_ren <= 1'b1;
              FFT    : fft_fifo_ren    <= 1'b1;
              endcase
           end
        end
      endcase
   end
   // ================================================================

   wire                            ft_fifo_empty;
   reg                             ft_fifo_ren = 1'b0;
   wire [`USB_DATA_WIDTH-1:0]      ft_fifo_rdata;
   reg [`USB_DATA_WIDTH-1:0]       ft_fifo_wdata;
   reg                             out_fifo_empty;
   reg                             ft_fifo_wen = 1'b0;

   localparam FLAG_WIDTH = $clog2(7);
   reg [FLAG_WIDTH-1:0] flag_ctr = {FLAG_WIDTH{1'b0}};
   reg [FLAG_WIDTH-1:0] max_flag_ctr;

   always @(*) begin
      case (out)
      RAW:
        begin
           ft_fifo_wdata  = ft_raw_data;
           out_fifo_empty = 1'b0;
           max_flag_ctr   = 2;
        end
      FIR:
        begin
           ft_fifo_wdata  = ft_fir_fifo_data;
           out_fifo_empty = fir_fifo_empty;
           max_flag_ctr   = 2;
        end
      WINDOW:
        begin
           ft_fifo_wdata  = ft_window_fifo_data;
           out_fifo_empty = window_fifo_empty;
           max_flag_ctr   = 2;
        end
      FFT:
        begin
           ft_fifo_wdata  = ft_fft_fifo_data;
           out_fifo_empty = fft_fifo_empty;
           max_flag_ctr   = 7;
        end
      endcase
   end

   async_fifo #(
      .WIDTH (`USB_DATA_WIDTH ),
      .DEPTH (FT_FIFO_DEPTH   )
   ) ft_fifo (
      .wclk         (clk80         ),
      .rst_n        (~stop_ftclk   ),
      .wen          (ft_fifo_wen   ),
      .wdata        (ft_fifo_wdata ),
      .rclk         (ft_clkout_i   ),
      .ren          (ft_fifo_ren   ),
      .empty        (ft_fifo_empty ),
      .rdata        (ft_fifo_rdata )
   );

   // ==================== FT clock state machine ====================
   localparam FTCLK_NUM_STATES = 18;
   localparam FTCLK_IDLE          = 0,
              FTCLK_READ_OE       = 1,
              FTCLK_READ          = 2,
              FTCLK_READ_INDIC    = 3,
              FTCLK_READ_START    = 4,
              FTCLK_READ_STOP     = 5,
              FTCLK_READ_CHANA    = 6,
              FTCLK_READ_CHANB    = 7,
              FTCLK_READ_OUTPUT   = 8,
              FTCLK_READ_ADF      = 9,
              FTCLK_READ_ADF_SEND = 10,
              FTCLK_TX_LOAD       = 11,
              FTCLK_TX_START      = 12,
              FTCLK_TX_DATA       = 13,
              FTCLK_TX_TXE        = 14,
              FTCLK_TX_LAST       = 15,
              FTCLK_TX_STOP       = 16,
              FTCLK_TX_WAIT       = 17;
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

   localparam CTR_WIDTH = 2;
   localparam [CTR_WIDTH-1:0] CTR_MAX = {CTR_WIDTH{1'b1}};
   reg [CTR_WIDTH-1:0]  ftclk_ctr;

   reg [1:0]            adf_ctr;
   always @(*) begin
      ftclk_next = {FTCLK_NUM_STATES{1'b0}};
      case (1'b1)
      ftclk_state[FTCLK_IDLE]          : if (~ft_rxf_n_i) ftclk_next[FTCLK_READ_OE] = 1'b1;
                                         else             ftclk_next[FTCLK_IDLE]    = 1'b1;

      // Read states
      ftclk_state[FTCLK_READ_OE]       :                                 ftclk_next[FTCLK_READ]          = 1'b1;
      ftclk_state[FTCLK_READ]          :                                 ftclk_next[FTCLK_READ_INDIC]    = 1'b1;
      ftclk_state[FTCLK_READ_INDIC]    : if (ft_data_io == 8'hFF)        ftclk_next[FTCLK_READ_STOP]     = 1'b1;
                                         else if (ft_data_io == 8'h00)   ftclk_next[FTCLK_READ_START]    = 1'b1;
                                         else if (ft_data_io[7] == 1'b1) ftclk_next[FTCLK_READ_ADF]      = 1'b1;
                                         else if (ft_data_io == 8'h01)   ftclk_next[FTCLK_READ_CHANA]    = 1'b1;
                                         else if (ft_data_io == 8'h02)   ftclk_next[FTCLK_READ_CHANB]    = 1'b1;
                                         else if (ft_data_io == 8'h03)   ftclk_next[FTCLK_READ_OUTPUT]   = 1'b1;
                                         // TODO this should never occur and can bring the state
                                         // machine into a temporary bad state
                                         else                            ftclk_next[FTCLK_IDLE]          = 1'b1;
      ftclk_state[FTCLK_READ_START]    : if (ftclk_ctr == CTR_MAX)       ftclk_next[FTCLK_TX_WAIT]       = 1'b1;
                                         else                            ftclk_next[FTCLK_READ_START]    = 1'b1;
      ftclk_state[FTCLK_READ_STOP]     : if (ftclk_ctr == CTR_MAX)       ftclk_next[FTCLK_IDLE]          = 1'b1;
                                         else                            ftclk_next[FTCLK_READ_STOP]     = 1'b1;
      ftclk_state[FTCLK_READ_CHANA]    : if (ftclk_ctr == CTR_MAX)       ftclk_next[FTCLK_READ]          = 1'b1;
                                         else                            ftclk_next[FTCLK_READ_CHANA]    = 1'b1;
      ftclk_state[FTCLK_READ_CHANB]    : if (ftclk_ctr == CTR_MAX)       ftclk_next[FTCLK_READ]          = 1'b1;
                                         else                            ftclk_next[FTCLK_READ_CHANB]    = 1'b1;
      ftclk_state[FTCLK_READ_OUTPUT]   : if (ftclk_ctr == CTR_MAX)       ftclk_next[FTCLK_READ]          = 1'b1;
                                         else                            ftclk_next[FTCLK_READ_OUTPUT]   = 1'b1;
      ftclk_state[FTCLK_READ_ADF]      : if (adf_ctr == 2'd3)            ftclk_next[FTCLK_READ_ADF_SEND] = 1'b1;
                                         else                            ftclk_next[FTCLK_READ_ADF]      = 1'b1;
      ftclk_state[FTCLK_READ_ADF_SEND] :                                 ftclk_next[FTCLK_READ]          = 1'b1;

      // TX states
      ftclk_state[FTCLK_TX_WAIT]       : if (state_ftclk_domain[TX])            ftclk_next[FTCLK_TX_LOAD]  = 1'b1;
                                         else                                   ftclk_next[FTCLK_TX_WAIT]  = 1'b1;
      ftclk_state[FTCLK_TX_LOAD]       : if (out_ftclk == RAW | out_fifo_empty) ftclk_next[FTCLK_TX_START] = 1'b1;
                                         else                                   ftclk_next[FTCLK_TX_LOAD]  = 1'b1;
      ftclk_state[FTCLK_TX_START]      : if (flag_ctr == max_flag_ctr)          ftclk_next[FTCLK_TX_DATA]  = 1'b1;
                                         else                                   ftclk_next[FTCLK_TX_START] = 1'b1;
      ftclk_state[FTCLK_TX_DATA]       : if (ft_fifo_empty)                     ftclk_next[FTCLK_TX_LAST]  = 1'b1;
                                         else if (ft_txe_n_i)                   ftclk_next[FTCLK_TX_TXE]   = 1'b1;
                                         else                                   ftclk_next[FTCLK_TX_DATA]  = 1'b1;
      ftclk_state[FTCLK_TX_TXE]        : if (~ft_txe_n_i)                       ftclk_next[FTCLK_TX_DATA]  = 1'b1;
                                         else                                   ftclk_next[FTCLK_TX_TXE]   = 1'b1;
      ftclk_state[FTCLK_TX_LAST]       : if (~ft_txe_n_i)                       ftclk_next[FTCLK_TX_STOP]  = 1'b1;
                                         else                                   ftclk_next[FTCLK_TX_LAST]  = 1'b1;
      ftclk_state[FTCLK_TX_STOP]       : if (flag_ctr == max_flag_ctr)          ftclk_next[FTCLK_TX_WAIT]  = 1'b1;
                                         else                                   ftclk_next[FTCLK_TX_STOP]  = 1'b1;

      default                          : ftclk_next[FTCLK_IDLE] = 1'b1;
      endcase
   end

   reg [`USB_DATA_WIDTH-1:0] ft_wr_data         = `USB_DATA_WIDTH'd0;
   reg [`USB_DATA_WIDTH-1:0] ft_fifo_rdata_last = `USB_DATA_WIDTH'd0;
   reg                       ft_txe_last        = 1'b0;
   always @(posedge ft_clkout_i) begin
      ft_oe_n_o        <= 1'b1;
      ft_rd_n_o        <= 1'b1;
      ftclk_ctr        <= {CTR_WIDTH{1'b0}};
      adf_ctr          <= 2'd0;
      start_ftclk      <= 1'b0;
      stop_ftclk       <= 1'b0;
      adf_reg_fifo_wen <= 1'b0;

      ft_wr_data  <= `USB_DATA_WIDTH'd0;
      ft_wr_n_o   <= 1'b1;
      tx_done     <= 1'b0;
      ft_txe_last <= ft_txe_n_i;
      flag_ctr    <= {FLAG_WIDTH{1'b0}};

      case (1'b1)
      // Read states
      ftclk_next[FTCLK_READ_OE]:
        begin
           ft_oe_n_o <= 1'b0;
        end
      ftclk_next[FTCLK_READ]:
        begin
           ft_oe_n_o <= 1'b0;
           ft_rd_n_o <= 1'b0;
        end
      ftclk_next[FTCLK_READ_INDIC]:
        begin
           ft_oe_n_o                  <= 1'b0;
           if (~ft_rxf_n_i) ft_rd_n_o <= 1'b0;
           adf_reg                    <= ft_data_io[2:0];
        end
      ftclk_next[FTCLK_READ_START]:
        begin
           ft_oe_n_o   <= 1'b0;
           ftclk_ctr   <= ftclk_ctr + 1'b1;
           start_ftclk <= 1'b1;
        end
      ftclk_next[FTCLK_READ_STOP]:
        begin
           ft_oe_n_o  <= 1'b0;
           ftclk_ctr  <= ftclk_ctr + 1'b1;
           stop_ftclk <= 1'b1;
        end
      ftclk_next[FTCLK_READ_CHANA]:
        begin
           ft_oe_n_o <= 1'b0;
           if (ftclk_ctr == {CTR_WIDTH{1'b0}}) begin
              if (~ft_rd_n_o) begin
                 use_chan_a_ftclk <= ft_data_io[0];
                 ftclk_ctr        <= ftclk_ctr + 1'b1;
                 ft_rd_n_o        <= 1'b1;
              end
              else if (~ft_rxf_n_i) ft_rd_n_o <= 1'b0;
           end
           else ftclk_ctr <= ftclk_ctr + 1'b1;
        end
      ftclk_next[FTCLK_READ_CHANB]:
        begin
           ft_oe_n_o <= 1'b0;
           if (ftclk_ctr == {CTR_WIDTH{1'b0}}) begin
              if (~ft_rd_n_o) begin
                 use_chan_b_ftclk <= ft_data_io[0];
                 ftclk_ctr        <= ftclk_ctr + 1'b1;
                 ft_rd_n_o        <= 1'b1;
              end
              else if (~ft_rxf_n_i) ft_rd_n_o <= 1'b0;
           end
           else ftclk_ctr <= ftclk_ctr + 1'b1;
        end
      ftclk_next[FTCLK_READ_OUTPUT]:
        begin
           ft_oe_n_o <= 1'b0;
           if (ftclk_ctr == {CTR_WIDTH{1'b0}}) begin
              if (~ft_rd_n_o) begin
                 out_ftclk <= ft_data_io[1:0];
                 ftclk_ctr <= ftclk_ctr + 1'b1;
                 ft_rd_n_o <= 1'b1;
              end
              else if (~ft_rxf_n_i) ft_rd_n_o <= 1'b0;
           end
           else ftclk_ctr <= ftclk_ctr + 1'b1;
        end
      ftclk_next[FTCLK_READ_ADF]:
        begin
           ft_oe_n_o                  <= 1'b0;
           if (~ft_rxf_n_i) ft_rd_n_o <= 1'b0;
           if (~ft_rd_n_o) begin
              case (adf_ctr)
              2'd0: adf_val[7:0]   <= ft_data_io;
              2'd1: adf_val[15:8]  <= ft_data_io;
              2'd2: adf_val[23:16] <= ft_data_io;
              2'd3: adf_val[31:24] <= ft_data_io;
              endcase
              adf_ctr <= adf_ctr + 1'b1;
           end
           else adf_ctr <= adf_ctr;
        end
      ftclk_next[FTCLK_READ_ADF_SEND]:
        begin
           ft_oe_n_o        <= 1'b0;
           ft_rd_n_o        <= 1'b1;
           adf_reg_fifo_wen <= 1'b1;
        end

      // TX states
      ftclk_next[FTCLK_TX_START]:
        begin
           ft_wr_data <= START_FLAG;
           ft_wr_n_o  <= 1'b0;
           if (~ft_txe_n_i) flag_ctr <= flag_ctr + 1'b1;
        end
      ftclk_next[FTCLK_TX_DATA] & ftclk_state[FTCLK_TX_TXE]:
        begin
           ft_wr_data <= ft_fifo_rdata_last;
           ft_wr_n_o  <= 1'b0;
        end
      (ftclk_next[FTCLK_TX_DATA] | ftclk_next[FTCLK_TX_LAST]) & ~ftclk_state[FTCLK_TX_TXE]:
        begin
           ft_wr_data         <= ft_fifo_rdata;
           ft_wr_n_o          <= 1'b0;
           ft_fifo_rdata_last <= ft_fifo_rdata;
        end
      ftclk_next[FTCLK_TX_STOP]:
        begin
           ft_wr_data <= STOP_FLAG;
           ft_wr_n_o  <= 1'b0;
           tx_done    <= 1'b1;
           if (~ft_txe_n_i) flag_ctr <= flag_ctr + 1'b1;
        end
      ftclk_next[FTCLK_TX_WAIT]:
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
      ftclk_next[FTCLK_TX_START] & (flag_ctr + 1'b1 == max_flag_ctr) : ft_fifo_ren = ~ft_txe_last;
      ftclk_next[FTCLK_TX_DATA]                                      : ft_fifo_ren = ~ft_txe_last;
      ftclk_next[FTCLK_TX_STOP]                                      : ft_fifo_ren = 1'b0;
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
   assign ext2_io[3] = ftclk_state[FTCLK_TX_DATA];
   assign ext2_io[1] = 1'b0;
   assign ext2_io[4] = ftclk_state[FTCLK_TX_WAIT];
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
