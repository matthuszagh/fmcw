`ifndef _TOP_V_
`define _TOP_V_

`define GPIO_WIDTH 6
`define USB_DATA_WIDTH 8
`define ADC_DATA_WIDTH 12
`define SD_DATA_WIDTH 4

`include "sync_fifo.v"
`include "async_fifo.v"
`include "ltc2292.v"
`include "ff_sync.v"
`include "adf4158.v"
`include "pll_sync_ctr.v"
`include "clk_enable.v"
`include "fir.v"
`include "window.v"
`include "fft.v"

`default_nettype none
`timescale 1ns/1ps

module top #(
   // TODO these are not properly parameterized
   parameter FIR_TAP_WIDTH      = 16,
   parameter FIR_NORM_SHIFT     = 4,
   parameter FIR_OUTPUT_WIDTH   = 13,
   parameter WINDOW_COEFF_WIDTH = 16,
   parameter FFT_TWIDDLE_WIDTH  = 18
) (
`ifdef TOP_SIMULATE
   input wire clk10,
   input wire clk20,
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
   inout wire [`USB_DATA_WIDTH-1:0]        ft_data_io,
   // Low when there is data in the buffer that can be read.
   input wire                              ft_rxf_n_i,
   // Low when there is room for transmission data in the FIFO.
   input wire                              ft_txe_n_i,
   // Drive low to load read data to ft_data_io each clock cycle.
   output reg                              ft_rd_n_o = 1'b1,
   // Drive low to write ft_data_io to FIFO for transmission.
   output reg                              ft_wr_n_o = 1'b1,
   // Flush transmission data to USB immediately.
   output wire                             ft_siwua_n_o,
   // 60MHz clock used to synchronize data transfers.
   input wire                              ft_clkout_i,
   // Drive low one period before ft_rd_n_o to signal read.
   output reg                              ft_oe_n_o = 1'b1,
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

   localparam NUM_STATES = 8;
   localparam IDLE        = 0,
              CONFIG      = 1,
              WAIT        = 2,
              SAMPLE      = 3,
              PROC_FILTER = 4,  // filter and window
              PROC_FFT    = 5,
              TX_LOAD     = 6,
              TX          = 7;
   reg [NUM_STATES-1:0] state;
   reg [NUM_STATES-1:0] next;

   assign pa_en_n_o    = ~state[SAMPLE];
   assign mix_enbl_n_o = 1'b0;
   assign adc_oe_o     = 2'b00;
   assign adc_shdn_o   = 2'b00;

`ifndef TOP_SIMULATE
   wire clk80;
   wire clk20;
   wire clk10;
   wire pll_lock;
   wire pll_fb;
   /* verilator lint_off DECLFILENAME */
   PLLE2_BASE #(
      .CLKFBOUT_MULT  (24 ),
      .DIVCLK_DIVIDE  (1  ),
      .CLKOUT0_DIVIDE (12 ),
      .CLKOUT1_DIVIDE (48 ),
      .CLKOUT2_DIVIDE (96 ),
      .CLKIN1_PERIOD  (25 )
   ) main_pll (
      .CLKOUT0  (clk80      ),
      .CLKOUT1  (clk20      ),
      .CLKOUT2  (clk10      ),
      .LOCKED   (pll_lock   ),
      .CLKIN1   (clk_i      ),
      .RST      (1'b0       ),
      .CLKFBOUT (pll_fb     ),
      .CLKFBIN  (pll_fb     )
   );
   /* verilator lint_on DECLFILENAME */
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

   /* verilator lint_off PINMISSING */
   wire clk2_pos_en;
   clk_enable #(
      .DIVIDE (DECIMATE)
   ) clk_enable (
      .clk_base (clk_i       ),
      .clk_en   (clk2_pos_en )
   );
   /* verilator lint_on PINMISSING */

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

   reg         adf_reg_fifo_wen = 1'b0;
   reg         adf_reg_fifo_ren = 1'b0;
   wire        adf_reg_fifo_empty;
   reg [2:0]   adf_reg;
   reg [31:0]  adf_val;
   wire [2:0]  adf_reg_sysclk;
   wire [31:0] adf_val_sysclk;
   /* verilator lint_off PINMISSING */
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
   /* verilator lint_on PINMISSING */
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
   /* verilator lint_off PINMISSING */
   sync_fifo #(
      .WIDTH (FIR_OUTPUT_WIDTH ),
      .DEPTH (FFT_N            )
   ) fir_fifo (
      .clk    (clk_i                      ),
      .srst_n (~stop                      ),
      .wen    (fir_fifo_wen & clk2_pos_en ),
      .wdata  (fir_out                    ),
      .ren    (fir_fifo_ren               ),
      .empty  (fir_fifo_empty             ),
      .rdata  (fir_fifo_rdata             )
   );
   /* verilator lint_on PINMISSING */

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
      .N           (FFT_N              ),
      .DATA_WIDTH  (FIR_OUTPUT_WIDTH   ),
      .COEFF_WIDTH (WINDOW_COEFF_WIDTH )
   ) window (
      .clk    (clk_i         ),
      .arst_n (~stop_ftclk   ),
      .en     (fir_dvalid    ),
      .clk_en (clk2_pos_en   ),
      .di     (fir_out       ),
      .dvalid (window_dvalid ),
      .dout   (window_out    )
   );

   wire                            window_fifo_empty;
   wire                            window_fifo_full;
   reg                             window_fifo_ren = 1'b0;
   wire [FIR_OUTPUT_WIDTH-1:0]     window_fifo_rdata;
   wire                            window_fifo_wen = window_dvalid;
   sync_fifo #(
      .WIDTH (FIR_OUTPUT_WIDTH ),
      .DEPTH (FFT_N            )
   ) window_fifo (
      .clk    (clk_i                         ),
      .srst_n (~stop                         ),
      .wen    (window_fifo_wen & clk2_pos_en ),
      .wdata  (window_out                    ),
      .ren    (window_fifo_ren               ),
      .empty  (window_fifo_empty             ),
      .full   (window_fifo_full              ),
      .rdata  (window_fifo_rdata             )
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

   reg                                fft_en = 1'b0;
   always @(posedge clk_i) begin
      if (window_fifo_ren & ~window_fifo_empty) fft_en <= 1'b1;
      else                                      fft_en <= 1'b0;
   end

   fft #(
      .N             (FFT_N             ),
      .INPUT_WIDTH   (FIR_OUTPUT_WIDTH  ),
      .TWIDDLE_WIDTH (FFT_TWIDDLE_WIDTH ),
      .OUTPUT_WIDTH  (FFT_OUTPUT_WIDTH  )
   ) fft (
      .clk        (clk_i                    ),
      .arst_n     (~stop_ftclk              ),
      .en         (fft_en                   ),
      .valid      (fft_valid                ),
      .data_ctr_o (fft_ctr                  ),
      .data_re_i  (window_fifo_rdata        ),
      .data_im_i  ({FIR_OUTPUT_WIDTH{1'b0}} ),
      .data_re_o  (fft_re_o                 ),
      .data_im_o  (fft_im_o                 )
   );

   localparam [$clog2(FFT_N)-1:0] FFT_N_MAX = {$clog2(FFT_N){1'b1}};
   reg [$clog2(FFT_N)-1:0]        fft_ram_raddr = {$clog2(FFT_N){1'b0}};
   reg                            fft_ram_empty = 1'b1;
   reg                            fft_ram_ren = 1'b0;
   wire [2*FFT_OUTPUT_WIDTH-1:0]  fft_ram_rdata;
   reg                            fft_ram_full = 1'b0;

   always @(posedge clk_i) begin
      if (stop) begin
         fft_ram_full <= 1'b0;
      end else begin
         if (fft_ctr == FFT_N_MAX & ~fft_ram_ren) begin
            fft_ram_full <= 1'b1;
         end else if (fft_ram_ren) begin
            fft_ram_full <= 1'b0;
         end
      end
   end

   always @(posedge clk10) begin
      if (stop) begin
         fft_ram_raddr  <= {$clog2(FFT_N){1'b0}};
         fft_ram_empty <= 1'b1;
      end else begin
         if (fft_ram_ren & ~fft_ram_empty) begin
            if (fft_ram_raddr == FFT_N_MAX) begin
               fft_ram_raddr  <= {$clog2(FFT_N){1'b0}};
               fft_ram_empty <= 1'b1;
            end else begin
               fft_ram_raddr  <= fft_ram_raddr + 1'b1;
               fft_ram_empty <= 1'b0;
            end
         end else if (fft_valid) begin
            fft_ram_empty <= 1'b0;
         end
      end
   end

   ram #(
      .WIDTH (2*FFT_OUTPUT_WIDTH ),
      .SIZE  (FFT_N              )
   ) fft_bitrev_ram (
      .wrclk  (clk_i                ),
      .wren   (fft_valid            ),
      .wraddr (fft_ctr              ),
      .wrdata ({fft_re_o, fft_im_o} ),
      .rdclk  (clk10                ),
      .rden   (fft_ram_ren         ),
      .rdaddr (fft_ram_raddr        ),
      .rddata (fft_ram_rdata       )
   );

   // TODO this is not properly parameterized. Currently, we assume
   // FIR_OUTPUT_WIDTH = 13, which gives FFT_OUTPUT_WIDTH = 24.
   // localparam FFT_REM_WIDTH = 64 - (2 * FFT_OUTPUT_WIDTH);
   reg [`USB_DATA_WIDTH-1:0] ft_fft_ram_data;
   always @(*) begin
      case (clk80_10_phase_ctr)
      3'd0: ft_fft_ram_data = 8'd0;
      3'd1: ft_fft_ram_data = 8'd0;
      3'd2: ft_fft_ram_data = fft_ram_rdata[47:40];
      3'd3: ft_fft_ram_data = fft_ram_rdata[39:32];
      3'd4: ft_fft_ram_data = fft_ram_rdata[31:24];
      3'd5: ft_fft_ram_data = fft_ram_rdata[23:16];
      3'd6: ft_fft_ram_data = fft_ram_rdata[15:8];
      3'd7: ft_fft_ram_data = fft_ram_rdata[7:0];
      endcase
   end

   // ============== System clock (40MHz) state machine ==============
   initial begin
      state       = {NUM_STATES{1'b0}};
      state[IDLE] = 1'b1;

      next       = {NUM_STATES{1'b0}};
      next[IDLE] = 1'b1;
   end

   reg [`USB_DATA_WIDTH-1:0]       ft_fifo_wdata;
   reg                             out_fifo_empty;
   wire                            out_fifo_empty_ftclk;

   always @(*) begin
      case (out)
      RAW:
        begin
           ft_fifo_wdata  = ft_raw_data;
           out_fifo_empty = 1'b0;
        end
      FIR:
        begin
           ft_fifo_wdata  = ft_fir_fifo_data;
           out_fifo_empty = fir_fifo_empty;
        end
      WINDOW:
        begin
           ft_fifo_wdata  = ft_window_fifo_data;
           out_fifo_empty = window_fifo_empty;
        end
      FFT:
        begin
           ft_fifo_wdata  = ft_fft_ram_data;
           out_fifo_empty = fft_ram_empty;
        end
      endcase
   end

   ff_sync #(
      .WIDTH  (1 ),
      .STAGES (2 )
   ) out_fifo_sync (
      .dest_clk (ft_clkout_i          ),
      .d        (out_fifo_empty       ),
      .q        (out_fifo_empty_ftclk )
   );

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
           if (stop)            next[IDLE]   = 1'b1;
           else if (adf_active) next[WAIT]   = 1'b1;
           else                 next[CONFIG] = 1'b1;
        end
      state[WAIT]:
        begin
           if (stop)                next[IDLE]   = 1'b1;
           else if (adf_ramp_start) next[SAMPLE] = 1'b1;
           else                     next[WAIT]   = 1'b1;
        end
      state[SAMPLE]:
        begin
           if (stop)                                   next[IDLE]        = 1'b1;
           else if (raw_sample_ctr == RAW_SAMPLES_MAX) next[PROC_FILTER] = 1'b1;
           else                                        next[SAMPLE]      = 1'b1;
        end
      state[PROC_FILTER]:
        begin
           if (stop)                  next[IDLE]        = 1'b1;
           else if (window_fifo_full) next[PROC_FFT]    = 1'b1;
           else                       next[PROC_FILTER] = 1'b1;
        end
      state[PROC_FFT]:
        begin
           if (stop)                           next[IDLE]     = 1'b1;
           else if (out < FFT | fft_ram_full) next[TX_LOAD]  = 1'b1;
           else                                next[PROC_FFT] = 1'b1;
        end
      state[TX_LOAD]:
        begin
           if (stop)                             next[IDLE]    = 1'b1;
           else if (out_fifo_empty | out == RAW) next[TX]      = 1'b1;
           else                                  next[TX_LOAD] = 1'b1;
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

   reg ft_fifo_wen = 1'b0;
   always @(posedge clk_i) begin
      raw_sample_ctr <= {RAW_SAMPLES{1'b0}};
      case (1'b1)
      state[SAMPLE] : raw_sample_ctr <= raw_sample_ctr + 1'b1;
      endcase

      ft_fifo_wen     <= 1'b0;
      window_fifo_ren <= 1'b0;
      fir_fifo_ren    <= 1'b0;

      case (1'b1)
      next[SAMPLE]: if (out == RAW) ft_fifo_wen <= 1'b1;
      next[PROC_FFT]:
        begin
           if (out == FFT) begin
              if (~window_fifo_empty) window_fifo_ren <= 1'b1;
              else                    window_fifo_ren <= 1'b0;
           end
        end
      next[TX_LOAD]:
        begin
           if (out != RAW) begin
              case (out)
              FIR:
                begin
                   fir_fifo_ren <= 1'b1;
                   if (fir_fifo_ren) ft_fifo_wen <= 1'b1;
                end
              WINDOW:
                begin
                   window_fifo_ren <= 1'b1;
                   if (window_fifo_ren) ft_fifo_wen <= 1'b1;
                end
              FFT: if (fft_ram_ren & (ft_fifo_wen | clk80_10_phase_ctr == 3'd7)) ft_fifo_wen <= 1'b1;
              endcase
           end
        end
      next[TX]:
        begin
           if (out == FFT & fft_ram_ren & clk80_10_phase_ctr < 3'd7) ft_fifo_wen <= 1'b1;
        end
      endcase
   end

   always @(posedge clk10) begin
      fft_ram_ren <= 1'b0;
      case (1'b1)
      next[TX_LOAD]: if (out == FFT) fft_ram_ren <= 1'b1;
      endcase
   end
   // ================================================================

   wire                            ft_fifo_empty;
   reg                             ft_fifo_ren = 1'b0;
   wire [`USB_DATA_WIDTH-1:0]      ft_fifo_rdata;

   localparam FLAG_WIDTH = $clog2(8);
   reg [FLAG_WIDTH-1:0] flag_ctr = {FLAG_WIDTH{1'b0}};
   reg [FLAG_WIDTH-1:0] max_flag_ctr;

   always @(*) begin
      case (out_ftclk)
      RAW    : max_flag_ctr = 1;
      FIR    : max_flag_ctr = 1;
      WINDOW : max_flag_ctr = 1;
      FFT    : max_flag_ctr = 7;
      endcase
   end

   /* verilator lint_off PINMISSING */
   async_fifo #(
      .WIDTH (`USB_DATA_WIDTH ),
      .DEPTH (FT_FIFO_DEPTH   )
   ) ft_fifo (
      .wclk  (clk80         ),
      .rst_n (~stop_ftclk   ),
      .wen   (ft_fifo_wen   ),
      .wdata (ft_fifo_wdata ),
      .rclk  (ft_clkout_i   ),
      .ren   (ft_fifo_ren   ),
      .empty (ft_fifo_empty ),
      .rdata (ft_fifo_rdata )
   );
   /* verilator lint_on PINMISSING */

   // ==================== FT clock state machine ====================
   localparam FTCLK_NUM_STATES = 29;
   localparam FTCLK_IDLE            = 0,
              FTCLK_READ_OE         = 1,
              FTCLK_READ_CMD_PRE    = 2,
              FTCLK_READ_CMD        = 3,
              FTCLK_READ_START      = 4,
              FTCLK_READ_STOP       = 5,
              FTCLK_READ_CHANA_PRE  = 6,
              FTCLK_READ_CHANA      = 7,
              FTCLK_READ_CHANB_PRE  = 8,
              FTCLK_READ_CHANB      = 9,
              FTCLK_READ_OUTPUT_PRE = 10,
              FTCLK_READ_OUTPUT     = 11,
              FTCLK_READ_ADF0_PRE   = 12,
              FTCLK_READ_ADF0       = 13,
              FTCLK_READ_ADF1_PRE   = 14,
              FTCLK_READ_ADF1       = 15,
              FTCLK_READ_ADF2_PRE   = 16,
              FTCLK_READ_ADF2       = 17,
              FTCLK_READ_ADF3_PRE   = 18,
              FTCLK_READ_ADF3       = 19,
              FTCLK_READ_ADF_SEND   = 20,
              FTCLK_TX_LOAD         = 21,
              FTCLK_TX_START        = 22,
              FTCLK_TX_DATA         = 23,
              FTCLK_TX_TXE          = 24,
              FTCLK_TX_LAST         = 25,
              FTCLK_TX_STOP         = 26,
              FTCLK_TX_DELAY        = 27,
              FTCLK_TX_WAIT         = 28;
   reg [FTCLK_NUM_STATES-1:0] ftclk_state;
   reg [FTCLK_NUM_STATES-1:0] ftclk_next;
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
   reg [CTR_WIDTH-1:0] ftclk_ctr;

   localparam DELAY = 4;
   localparam [$clog2(DELAY)-1:0] DELAY_MAX = DELAY - 1;
   reg [$clog2(DELAY)-1:0] delay_ctr;

   reg [`USB_DATA_WIDTH-1:0] ft_rd_data;
   always @(*) begin
      ftclk_next = {FTCLK_NUM_STATES{1'b0}};
      case (1'b1)
      ftclk_state[FTCLK_IDLE]          : if (~ft_rxf_n_i) ftclk_next[FTCLK_READ_OE] = 1'b1;
                                         else             ftclk_next[FTCLK_IDLE]    = 1'b1;

      // Read states
      ftclk_state[FTCLK_READ_OE]         :                                 ftclk_next[FTCLK_READ_CMD_PRE]    = 1'b1;
      ftclk_state[FTCLK_READ_CMD_PRE]    : if (~ft_rd_n_o)                 ftclk_next[FTCLK_READ_CMD]        = 1'b1;
                                           else                            ftclk_next[FTCLK_READ_CMD_PRE]    = 1'b1;
      ftclk_state[FTCLK_READ_CMD]        : if (ft_rd_data == 8'hFF)        ftclk_next[FTCLK_READ_STOP]       = 1'b1;
                                           else if (ft_rd_data == 8'h00)   ftclk_next[FTCLK_READ_START]      = 1'b1;
                                           else if (ft_rd_data[7] == 1'b1) ftclk_next[FTCLK_READ_ADF0_PRE]   = 1'b1;
                                           else if (ft_rd_data == 8'h01)   ftclk_next[FTCLK_READ_CHANA_PRE]  = 1'b1;
                                           else if (ft_rd_data == 8'h02)   ftclk_next[FTCLK_READ_CHANB_PRE]  = 1'b1;
                                           else if (ft_rd_data == 8'h03)   ftclk_next[FTCLK_READ_OUTPUT_PRE] = 1'b1;
                                           // TODO this should never occur and can bring the state
                                           // machine into a temporary bad state
                                           else                            ftclk_next[FTCLK_IDLE]            = 1'b1;
      ftclk_state[FTCLK_READ_START]      : if (ftclk_ctr == CTR_MAX)       ftclk_next[FTCLK_TX_WAIT]         = 1'b1;
                                           else                            ftclk_next[FTCLK_READ_START]      = 1'b1;
      ftclk_state[FTCLK_READ_STOP]       : if (ftclk_ctr == CTR_MAX)       ftclk_next[FTCLK_IDLE]            = 1'b1;
                                           else                            ftclk_next[FTCLK_READ_STOP]       = 1'b1;
      ftclk_state[FTCLK_READ_CHANA_PRE]  : if (~ft_rd_n_o)                 ftclk_next[FTCLK_READ_CHANA]      = 1'b1;
                                           else                            ftclk_next[FTCLK_READ_CHANA_PRE]  = 1'b1;
      ftclk_state[FTCLK_READ_CHANA]      : if (ftclk_ctr == CTR_MAX)       ftclk_next[FTCLK_READ_CMD_PRE]    = 1'b1;
                                           else                            ftclk_next[FTCLK_READ_CHANA]      = 1'b1;
      ftclk_state[FTCLK_READ_CHANB_PRE]  : if (~ft_rd_n_o)                 ftclk_next[FTCLK_READ_CHANB]      = 1'b1;
                                           else                            ftclk_next[FTCLK_READ_CHANB_PRE]  = 1'b1;
      ftclk_state[FTCLK_READ_CHANB]      : if (ftclk_ctr == CTR_MAX)       ftclk_next[FTCLK_READ_CMD_PRE]    = 1'b1;
                                           else                            ftclk_next[FTCLK_READ_CHANB]      = 1'b1;
      ftclk_state[FTCLK_READ_OUTPUT_PRE] : if (~ft_rd_n_o)                 ftclk_next[FTCLK_READ_OUTPUT]     = 1'b1;
                                           else                            ftclk_next[FTCLK_READ_OUTPUT_PRE] = 1'b1;
      ftclk_state[FTCLK_READ_OUTPUT]     : if (ftclk_ctr == CTR_MAX)       ftclk_next[FTCLK_READ_CMD_PRE]    = 1'b1;
                                           else                            ftclk_next[FTCLK_READ_OUTPUT]     = 1'b1;
      ftclk_state[FTCLK_READ_ADF0_PRE]   : if (~ft_rd_n_o)                 ftclk_next[FTCLK_READ_ADF0]       = 1'b1;
                                           else                            ftclk_next[FTCLK_READ_ADF0_PRE]   = 1'b1;
      ftclk_state[FTCLK_READ_ADF0]       :                                 ftclk_next[FTCLK_READ_ADF1_PRE]   = 1'b1;
      ftclk_state[FTCLK_READ_ADF1_PRE]   : if (~ft_rd_n_o)                 ftclk_next[FTCLK_READ_ADF1]       = 1'b1;
                                           else                            ftclk_next[FTCLK_READ_ADF1_PRE]   = 1'b1;
      ftclk_state[FTCLK_READ_ADF1]       :                                 ftclk_next[FTCLK_READ_ADF2_PRE]   = 1'b1;
      ftclk_state[FTCLK_READ_ADF2_PRE]   : if (~ft_rd_n_o)                 ftclk_next[FTCLK_READ_ADF2]       = 1'b1;
                                           else                            ftclk_next[FTCLK_READ_ADF2_PRE]   = 1'b1;
      ftclk_state[FTCLK_READ_ADF2]       :                                 ftclk_next[FTCLK_READ_ADF3_PRE]   = 1'b1;
      ftclk_state[FTCLK_READ_ADF3_PRE]   : if (~ft_rd_n_o)                 ftclk_next[FTCLK_READ_ADF3]       = 1'b1;
                                           else                            ftclk_next[FTCLK_READ_ADF3_PRE]   = 1'b1;
      ftclk_state[FTCLK_READ_ADF3]       :                                 ftclk_next[FTCLK_READ_ADF_SEND]   = 1'b1;
      ftclk_state[FTCLK_READ_ADF_SEND]   :                                 ftclk_next[FTCLK_READ_CMD_PRE]    = 1'b1;

      // TX states
      ftclk_state[FTCLK_TX_WAIT]         : if (~ft_rxf_n_i)                             ftclk_next[FTCLK_READ_OE]  = 1'b1;
                                           else if (state_ftclk_domain[TX_LOAD])        ftclk_next[FTCLK_TX_LOAD]  = 1'b1;
                                           else                                         ftclk_next[FTCLK_TX_WAIT]  = 1'b1;
      ftclk_state[FTCLK_TX_LOAD]         : if (out_ftclk == RAW | out_fifo_empty_ftclk) ftclk_next[FTCLK_TX_START] = 1'b1;
                                           else                                         ftclk_next[FTCLK_TX_LOAD]  = 1'b1;
      ftclk_state[FTCLK_TX_START]        : if (flag_ctr == max_flag_ctr)                ftclk_next[FTCLK_TX_DATA]  = 1'b1;
                                           else                                         ftclk_next[FTCLK_TX_START] = 1'b1;
      ftclk_state[FTCLK_TX_DATA]         : if (ft_fifo_empty)                           ftclk_next[FTCLK_TX_LAST]  = 1'b1;
                                           else if (ft_txe_n_i)                         ftclk_next[FTCLK_TX_TXE]   = 1'b1;
                                           else                                         ftclk_next[FTCLK_TX_DATA]  = 1'b1;
      ftclk_state[FTCLK_TX_TXE]          : if (~ft_txe_n_i)                             ftclk_next[FTCLK_TX_DATA]  = 1'b1;
                                           else                                         ftclk_next[FTCLK_TX_TXE]   = 1'b1;
      ftclk_state[FTCLK_TX_LAST]         : if (~ft_txe_n_i)                             ftclk_next[FTCLK_TX_STOP]  = 1'b1;
                                           else                                         ftclk_next[FTCLK_TX_LAST]  = 1'b1;
      ftclk_state[FTCLK_TX_STOP]         : if (flag_ctr == max_flag_ctr)                ftclk_next[FTCLK_TX_DELAY] = 1'b1;
                                           else                                         ftclk_next[FTCLK_TX_STOP]  = 1'b1;
      ftclk_state[FTCLK_TX_DELAY]        : if (delay_ctr == DELAY_MAX)                  ftclk_next[FTCLK_TX_WAIT]  = 1'b1;
                                           else                                         ftclk_next[FTCLK_TX_DELAY] = 1'b1;

      default                            : ftclk_next[FTCLK_IDLE] = 1'b1;
      endcase
   end

   always @(posedge ft_clkout_i) begin
      if (~ft_rxf_n_i & ~ft_rd_n_o) ft_rd_data <= ft_data_io;
   end

   reg [`USB_DATA_WIDTH-1:0] ft_wr_data         = `USB_DATA_WIDTH'd0;
   reg [`USB_DATA_WIDTH-1:0] ft_fifo_rdata_last = `USB_DATA_WIDTH'd0;
   reg                       ft_txe_last        = 1'b0;
   reg                       ft_txe_last2       = 1'b0;
   always @(posedge ft_clkout_i) begin
      ft_oe_n_o        <= 1'b1;
      ft_rd_n_o        <= 1'b1;
      adf_reg_fifo_wen <= 1'b0;

      ft_wr_n_o    <= 1'b1;
      tx_done      <= 1'b0;
      ft_txe_last  <= ft_txe_n_i;
      ft_txe_last2 <= ft_txe_last;

      ft_fifo_ren <= 1'b0;

      case (1'b1)
      // Read states
      ftclk_next[FTCLK_READ_OE]: ft_oe_n_o <= 1'b0;
      ftclk_next[FTCLK_READ_CMD_PRE]:
        begin
           ft_oe_n_o <= 1'b0;
           if (~ft_rxf_n_i) ft_rd_n_o <= 1'b0;
        end
      ftclk_next[FTCLK_READ_CMD]: ft_oe_n_o <= 1'b0;
      ftclk_next[FTCLK_READ_START]: ft_oe_n_o <= 1'b0;
      ftclk_next[FTCLK_READ_STOP]: ft_oe_n_o <= 1'b0;
      ftclk_next[FTCLK_READ_CHANA_PRE]:
        begin
           ft_oe_n_o <= 1'b0;
           if (~ft_rxf_n_i) ft_rd_n_o <= 1'b0;
        end
      ftclk_next[FTCLK_READ_CHANA]: ft_oe_n_o <= 1'b0;
      ftclk_next[FTCLK_READ_CHANB_PRE]:
        begin
           ft_oe_n_o <= 1'b0;
           if (~ft_rxf_n_i) ft_rd_n_o <= 1'b0;
        end
      ftclk_next[FTCLK_READ_CHANB]: ft_oe_n_o <= 1'b0;
      ftclk_next[FTCLK_READ_OUTPUT_PRE]:
        begin
           ft_oe_n_o <= 1'b0;
           if (~ft_rxf_n_i) ft_rd_n_o <= 1'b0;
        end
      ftclk_next[FTCLK_READ_OUTPUT]: ft_oe_n_o <= 1'b0;
      ftclk_next[FTCLK_READ_ADF0_PRE]:
        begin
           ft_oe_n_o <= 1'b0;
           if (~ft_rxf_n_i) ft_rd_n_o <= 1'b0;
        end
      ftclk_next[FTCLK_READ_ADF0]: ft_oe_n_o <= 1'b0;
      ftclk_next[FTCLK_READ_ADF1_PRE]:
        begin
           ft_oe_n_o <= 1'b0;
           if (~ft_rxf_n_i) ft_rd_n_o <= 1'b0;
        end
      ftclk_next[FTCLK_READ_ADF1]: ft_oe_n_o <= 1'b0;
      ftclk_next[FTCLK_READ_ADF2_PRE]:
        begin
           ft_oe_n_o <= 1'b0;
           if (~ft_rxf_n_i) ft_rd_n_o <= 1'b0;
        end
      ftclk_next[FTCLK_READ_ADF2]: ft_oe_n_o <= 1'b0;
      ftclk_next[FTCLK_READ_ADF3_PRE]:
        begin
           ft_oe_n_o <= 1'b0;
           if (~ft_rxf_n_i) ft_rd_n_o <= 1'b0;
        end
      ftclk_next[FTCLK_READ_ADF3]: ft_oe_n_o <= 1'b0;
      ftclk_next[FTCLK_READ_ADF_SEND]:
        begin
           ft_oe_n_o        <= 1'b0;
           adf_reg_fifo_wen <= 1'b1;
        end

      // TX states
      ftclk_next[FTCLK_TX_START]:
        begin
           ft_wr_data <= START_FLAG;
           ft_wr_n_o  <= 1'b0;
           if (out == FFT) begin
              if (flag_ctr == max_flag_ctr - 2'd2 | ft_fifo_ren) ft_fifo_ren <= ~ft_txe_last;
              else                                               ft_fifo_ren <= 1'b0;
           end
           else ft_fifo_ren <= ~ft_txe_last;
        end
      ftclk_next[FTCLK_TX_TXE] & ftclk_state[FTCLK_TX_DATA]:
        begin
           ft_fifo_rdata_last <= ft_fifo_rdata;
        end
      ftclk_next[FTCLK_TX_DATA] & ftclk_state[FTCLK_TX_TXE]:
        begin
           ft_wr_n_o <= 1'b0;
        end
      (ftclk_next[FTCLK_TX_DATA] | ftclk_next[FTCLK_TX_LAST]) & ~ftclk_state[FTCLK_TX_TXE]:
        begin
           if (ft_txe_last2) ft_wr_data <= ft_fifo_rdata_last;
           else              ft_wr_data <= ft_fifo_rdata;
           ft_wr_n_o          <= 1'b0;
           ft_fifo_ren        <= 1'b1;
        end
      ftclk_next[FTCLK_TX_STOP]:
        begin
           ft_wr_data <= STOP_FLAG;
           ft_wr_n_o  <= 1'b0;
           tx_done    <= 1'b1;
        end
      endcase
   end

   always @(posedge ft_clkout_i) begin
      ftclk_ctr   <= {CTR_WIDTH{1'b0}};
      delay_ctr   <= {$clog2(DELAY){1'b0}};
      start_ftclk <= 1'b0;
      stop_ftclk  <= 1'b0;
      flag_ctr    <= {FLAG_WIDTH{1'b0}};

      case (1'b1)
      ftclk_state[FTCLK_READ_CMD]: adf_reg <= ft_rd_data[2:0];
      ftclk_state[FTCLK_READ_START]:
        begin
           ftclk_ctr   <= ftclk_ctr + 1'b1;
           start_ftclk <= 1'b1;
        end
      ftclk_state[FTCLK_READ_STOP]:
        begin
           ftclk_ctr  <= ftclk_ctr + 1'b1;
           stop_ftclk <= 1'b1;
        end
      ftclk_state[FTCLK_READ_CHANA]:
        begin
           ftclk_ctr <= ftclk_ctr + 1'b1;
           if (ftclk_ctr == {CTR_WIDTH{1'b0}}) use_chan_a_ftclk <= ft_rd_data[0];
        end
      ftclk_state[FTCLK_READ_CHANB]:
        begin
           ftclk_ctr <= ftclk_ctr + 1'b1;
           if (ftclk_ctr == {CTR_WIDTH{1'b0}}) use_chan_b_ftclk <= ft_rd_data[0];
        end
      ftclk_state[FTCLK_READ_OUTPUT]:
        begin
           ftclk_ctr <= ftclk_ctr + 1'b1;
           if (ftclk_ctr == {CTR_WIDTH{1'b0}}) out_ftclk <= ft_rd_data[1:0];
        end
      ftclk_state[FTCLK_READ_ADF0]: adf_val[7:0] <= ft_rd_data;
      ftclk_state[FTCLK_READ_ADF1]: adf_val[15:8] <= ft_rd_data;
      ftclk_state[FTCLK_READ_ADF2]: adf_val[23:16] <= ft_rd_data;
      ftclk_state[FTCLK_READ_ADF3]: adf_val[31:24] <= ft_rd_data;

      // TX states
      ftclk_state[FTCLK_TX_START]:
        begin
           if (~ft_txe_n_i) flag_ctr <= flag_ctr + 1'b1;
           else             flag_ctr <= flag_ctr;
        end
      ftclk_state[FTCLK_TX_STOP]:
        begin
           if (~ft_txe_n_i) flag_ctr <= flag_ctr + 1'b1;
           else             flag_ctr <= flag_ctr;
        end
      ftclk_state[FTCLK_TX_DELAY]: delay_ctr <= delay_ctr + 1'b1;
      endcase
   end
   // ================================================================

   assign ft_data_io = ft_oe_n_o ? ft_wr_data : {`USB_DATA_WIDTH{1'bz}};

   assign ext1_io[0] = 1'b0;
   assign ext1_io[3] = adf_muxout_i;
   assign ext1_io[1] = 1'b0;
   assign ext1_io[4] = fft_valid;
   assign ext1_io[2] = 1'b0;
   assign ext1_io[5] = fft_ram_ren;

   assign ext2_io[0] = 1'b0;
   assign ext2_io[3] = state[SAMPLE];
   assign ext2_io[1] = 1'b0;
   assign ext2_io[4] = state[PROC_FILTER];
   assign ext2_io[2] = 1'b0;
   assign ext2_io[5] = state[TX];

endmodule

`ifdef TOP_SIMULATE
`include "sync_fifo.v"
module top_tb;

   reg clk10  = 1'b0;
   reg clk20  = 1'b0;
   reg clk40  = 1'b0;
   reg clk60  = 1'b0;
   reg clk80  = 1'b0;

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

   integer i;
   initial begin
      $dumpfile("tb/top_tb.vcd");
      $dumpvars(0, top_tb);
      for (i=0; i<10; i=i+1) $dumpvars(0, dut.adf4158.r[i]);
      #10000000 $finish;
   end

   always #12.5 clk40 = ~clk40;
   always #8.33 clk60 = ~clk60;

   initial begin
      #12.5;
      clk10 = ~clk10;
      forever clk10 = #50 ~clk10;
   end

   initial begin
      #12.5;
      clk20 = ~clk20;
      forever clk20 = #25 ~clk20;
   end

   initial begin
      #12.5;
      clk80 = ~clk80;
      forever clk80 = #6.25 ~clk80;
   end

   reg ft_txe_n = 1'b0;
   integer ft_txe_on_ctr = 0;
   integer ft_txe_off_ctr = 0;
   // Note: uncomment if you want to test effect of ft_txe_n.
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

   localparam NUM_RBYTES = 47;
   reg [7:0] ft245_rdata [0:NUM_RBYTES-1];
   initial begin
      // chan A
      ft245_rdata[0]  = 8'h01;
      ft245_rdata[1]  = 8'h00;
      // chan B
      ft245_rdata[2]  = 8'h02;
      ft245_rdata[3]  = 8'h01;
      // output
      ft245_rdata[4]  = 8'h03;
      ft245_rdata[5]  = 8'h03;
      // adf reg 0
      ft245_rdata[6]  = 8'h80;
      ft245_rdata[7]  = 8'h00;
      ft245_rdata[8]  = 8'h00;
      ft245_rdata[9]  = 8'h8C;
      ft245_rdata[10] = 8'h78;
      // adf reg 1
      ft245_rdata[11] = 8'h81;
      ft245_rdata[12] = 8'h01;
      ft245_rdata[13] = 8'h00;
      ft245_rdata[14] = 8'h00;
      ft245_rdata[15] = 8'h00;
      // adf reg 2
      ft245_rdata[16] = 8'h82;
      ft245_rdata[17] = 8'h52;
      ft245_rdata[18] = 8'h80;
      ft245_rdata[19] = 8'h60;
      ft245_rdata[20] = 8'h10;
      // adf reg 3
      ft245_rdata[21] = 8'h83;
      ft245_rdata[22] = 8'h43;
      ft245_rdata[23] = 8'h80;
      ft245_rdata[24] = 8'h00;
      ft245_rdata[25] = 8'h00;
      // adf reg 4
      ft245_rdata[26] = 8'h84;
      ft245_rdata[27] = 8'h84;
      ft245_rdata[28] = 8'h00;
      ft245_rdata[29] = 8'h78;
      ft245_rdata[30] = 8'h00;
      // adf reg 5
      ft245_rdata[31] = 8'h85;
      ft245_rdata[32] = 8'h85;
      ft245_rdata[33] = 8'h00;
      ft245_rdata[34] = 8'h20;
      ft245_rdata[35] = 8'h00;
      // adf reg 6
      ft245_rdata[36] = 8'h86;
      ft245_rdata[37] = 8'h86;
      ft245_rdata[38] = 8'h3E;
      ft245_rdata[39] = 8'h00;
      ft245_rdata[40] = 8'h00;
      // adf reg 7
      ft245_rdata[41] = 8'h87;
      ft245_rdata[42] = 8'h07;
      ft245_rdata[43] = 8'h7D;
      ft245_rdata[44] = 8'h03;
      ft245_rdata[45] = 8'h00;
      // start
      ft245_rdata[46] = 8'h00;
   end

   wire       ft_rd_n;
   reg [$clog2(NUM_RBYTES)-1:0] ctr = 0;
   always @(posedge clk60) begin
      if (~ft_oe_n & ~ft_rd_n) ctr <= ctr + 1'b1;
   end

   wire [`USB_DATA_WIDTH-1:0] ft_data_io;
   wire                       ft_oe_n;
   assign ft_data_io = ft_oe_n ? 8'dz : (~ft_rd_n ? ft245_rdata[ctr] : 8'hxx);
   top #(
      .FIR_TAP_WIDTH     (16 ),
      .FIR_NORM_SHIFT    (4  ),
      .FIR_OUTPUT_WIDTH  (13 ),
      .FFT_TWIDDLE_WIDTH (18 )
   ) dut (
      .clk10          (clk10                   ),
      .clk20          (clk20                   ),
      .clk80          (clk80                   ),
      .clk_i          (clk40                   ),
      .ft_data_io     (ft_data_io              ),
      .ft_rxf_n_i     (~(ctr < NUM_RBYTES)     ),
      .ft_txe_n_i     (ft_txe_n                ),
      .ft_oe_n_o      (ft_oe_n                 ),
      .ft_rd_n_o      (ft_rd_n                 ),
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
   integer                    rx_ctr = 0;
   always @(posedge clk60) begin
      if (~ft_txe_n & ~dut.ft_wr_n_o) begin
         data_rx <= ft_data_io;
         rx_ctr <= rx_ctr + 1;
      end
      else data_rx <= `USB_DATA_WIDTH'dx;
   end

endmodule
`endif

`undef GPIO_WIDTH
`undef USB_DATA_WIDTH
`undef ADC_DATA_WIDTH
`undef SD_DATA_WIDTH
`endif
