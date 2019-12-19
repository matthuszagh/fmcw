`default_nettype none

`include "control.v"
`include "ltc2292.v"
`include "adf4158.v"
`include "ft245.v"
`include "fir_poly.v"
`include "window.v"
`include "fft_r22sdf.v"

module top #(
   parameter GPIO_WIDTH       = 6,
   parameter USB_DATA_WIDTH   = 8,
   parameter ADC_DATA_WIDTH   = 12,
   parameter SD_DATA_WIDTH    = 4,
   parameter FIR_OUTPUT_WIDTH = 14
) (
   // =============== clocks, resets, LEDs, connectors ===============
   // 40MHz
   input wire                             clk_i,
   output wire                            led_o,
   // General-purpose I/O.
   inout wire [GPIO_WIDTH-1:0]            ext1_io,
   inout wire [GPIO_WIDTH-1:0]            ext2_io,

   // can't simulate the PLL so we provide them from external logic.
`ifdef COCOTB_SIM
   input wire                             clk_7_5mhz,
   input wire                             clk_120mhz,
   input wire                             clk_80mhz,
   input wire                             clk_20mhz,
   input wire                             pll_lock,
`endif

   // ==================== FT2232H USB interface. ====================
   // FIFO data
   inout wire signed [USB_DATA_WIDTH-1:0] ft_data_io,
   // Low when there is data in the buffer that can be read.
   input wire                             ft_rxf_n_i,
   // Low when there is room for transmission data in the FIFO.
   input wire                             ft_txe_n_i,
   // Drive low to load read data to ft_data_io each clock cycle.
   output wire                            ft_rd_n_o,
   // Drive low to write ft_data_io to FIFO for transmission.
   output wire                            ft_wr_n_o,
   // Flush transmission data to USB immediately.
   output wire                            ft_siwua_n_o,
   // 60MHz clock used to synchronize data transfers.
   input wire                             ft_clkout_i,
   // Drive low one period before ft_rd_n_o to signal read.
   output wire                            ft_oe_n_o,
   // Low when USB in suspend mode.
   input wire                             ft_suspend_n_i,

   // ============================== ADC =============================
   // Input data from ADC.
   input wire signed [ADC_DATA_WIDTH-1:0] adc_d_i,
   // High value indicates overflow or underflow.
   input wire [1:0]                       adc_of_i,
   // 10 turns on channel A and turns off channel B.
   output reg [1:0]                       adc_oe_o,
   // Same state as adc_oe.
   output reg [1:0]                       adc_shdn_o,

   // ============================ SD card ===========================
   // TODO: Setup option to load bitstream from SD card.
   inout wire [SD_DATA_WIDTH-1:0]         sd_data_i,
   inout wire                             sd_cmd_i,
   output reg                             sd_clk_o = 1'b0,
   input wire                             sd_detect_i,

   // ============================= mixer ============================
   // Low voltage enables mixer.
   output reg                             mix_enbl_n_o,

   // ======================== power amplifier =======================
   output wire                            pa_en_n_o,

   // ===================== frequency synthesizer ====================
   output wire                            adf_ce_o,
   output wire                            adf_le_o,
   output wire                            adf_clk_o,
   input wire                             adf_muxout_i,
   output wire                            adf_txdata_o,
   output wire                            adf_data_o,
   // input wire                             adf_done_i,

   // ========================= flash storage ========================
   // TODO: Configure flash to save bitstream configuration across boot cycles.
   output reg                             flash_cs_n_o = 1'b1,
   input wire                             flash_miso_i,
   output reg                             flash_mosi_o = 1'b0
);

   localparam FFT_N   = 1024;
   /* verilator lint_off WIDTH */
   localparam [$clog2(FFT_N-1)-1:0] FFT_N_CMP = FFT_N - 1;
   /* verilator lint_on WIDTH */

   assign led_o       = ~pa_en_n_o;
   assign ext1_io[0]  = ramp_on;
   assign ext1_io[1]  = ramp_start;
   assign ext1_io[2]  = ft245_wrfifo_empty;
   assign ext1_io[3]  = ft245_wrfifo_full;
   assign ext1_io[4]  = adf_en;

   always @(posedge clk_i) begin
      // Multiplex both channels through A, so we can disable channel
      // B. OE should remain on for A since the switching speed isn't
      // fast enough to switch it on and off (datasheet p22).
      adc_oe_o <= 2'b10;
      // Similarly leave the shutdown pin on. If we need to conserve
      // power we can set this to use nap mode when not in
      // use. However, that requires about 100 clock cycles to
      // recover.
      adc_shdn_o <= 2'b00;
      // Keep mixer on so we don't have to worry about enable and
      // disable times.
      mix_enbl_n_o <= 1'b0;
   end
   assign pa_en_n_o = ~ramp_on;

`ifndef COCOTB_SIM
   /**
    * Drives onboard logic.
    */
   wire                            clk_120mhz;
   wire                            clk_80mhz;
   wire                            clk_20mhz;
   wire                            pll_lock;
   wire                            pll_fb;
   /* verilator lint_off DECLFILENAME */
   PLLE2_BASE #(
      .CLKFBOUT_MULT  (24 ),
      .DIVCLK_DIVIDE  (1  ),
      .CLKOUT0_DIVIDE (8  ),
      .CLKOUT1_DIVIDE (48 ),
      .CLKOUT2_DIVIDE (12 ),
      .CLKIN1_PERIOD  (25 )
   ) main_pll (
      .CLKOUT0  (clk_120mhz ),
      .CLKOUT1  (clk_20mhz  ),
      .CLKOUT2  (clk_80mhz  ),
      .LOCKED   (pll_lock   ),
      .CLKIN1   (clk_i      ),
      .RST      (1'b0       ),
      .CLKFBOUT (pll_fb     ),
      .CLKFBIN  (pll_fb     )
   );
   /* verilator lint_on DECLFILENAME */

   /**
    * Drives FT2232H side of data transmission between FPGA and
    * FT2232H.
    */
   wire                            clk_7_5mhz;
   wire                            clk_22_5mhz;
   wire                            ft_pll_lock;
   wire                            ft_pll_fb;
   PLLE2_BASE #(
      .CLKFBOUT_MULT  (15    ),
      .DIVCLK_DIVIDE  (1     ),
      .CLKOUT0_DIVIDE (120   ),
      .CLKOUT1_DIVIDE (40    ),
      .CLKIN1_PERIOD  (16.67 )
   ) ft_pll (
      .CLKOUT0  (clk_7_5mhz  ),
      .CLKOUT1  (clk_22_5mhz ),
      .LOCKED   (ft_pll_lock ),
      .CLKIN1   (ft_clkout_i ),
      .RST      (1'b0        ),
      .CLKFBOUT (ft_pll_fb   ),
      .CLKFBIN  (ft_pll_fb   )
   );
`endif
   wire                            rst_n = pll_lock;

   // Generate 2MHz and 4MHz clock enables.
   reg                             clk_2mhz_pos_en = 1'b1;
   reg [4:0]                       clk_2mhz_ctr    = 5'd0;

   always @(posedge clk_i) begin
      if (clk_2mhz_ctr == 5'd19) begin
         clk_2mhz_pos_en <= 1'b1;
         clk_2mhz_ctr    <= 5'd0;
      end else begin
         clk_2mhz_pos_en <= 1'b0;
         clk_2mhz_ctr    <= clk_2mhz_ctr + 1'b1;
      end
   end

   wire adf_en;
   wire fir_en;
   wire fifo_wren;
   wire fifo_rden;
   wire fft_en;
   reg  ft245_en;
   control control (
      .clk          (clk_i               ),
      .rst_n        (rst_n               ),
      .adf_done     (adf_config_done     ),
      .ramp_start   (ramp_start          ),
      .window_valid (kaiser_dvalid       ),
      .fifo_full    (fir_fft_fifo_full   ),
      .fft_done     (fft_ctr == 10'd1023 ),
      .ft245_empty  (ft245_wrfifo_empty  ),
      .adf_en       (adf_en              ),
      .fir_en       (fir_en              ),
      .fifo_wren    (fifo_wren           ),
      .fifo_rden    (fifo_rden           ),
      .fft_en       (fft_en              )
   );

   wire                            adf_config_done;
   wire                            ramp_start;
   wire                            ramp_on;
   adf4158 adf4158 (
      .clk         (clk_i           ),
      .clk_20mhz   (clk_20mhz       ),
      .rst_n       (pll_lock        ),
      .enable      (adf_en          ),
      .config_done (adf_config_done ),
      .le          (adf_le_o        ),
      .ce          (adf_ce_o        ),
      .muxout      (adf_muxout_i    ),
      .ramp_start  (ramp_start      ),
      .ramp_on     (ramp_on         ),
      .txdata      (adf_txdata_o    ),
      .data        (adf_data_o      )
   );
   assign adf_clk_o = clk_20mhz;

   wire signed [ADC_DATA_WIDTH-1:0] chan_a;
   wire signed [ADC_DATA_WIDTH-1:0] chan_b;
   ltc2292 ltc2292 (
      .clk (clk_i   ),
      .di  (adc_d_i ),
      .dao (chan_a  ),
      .dbo (chan_b  )
   );

   wire signed [FIR_OUTPUT_WIDTH-1:0] chan_a_filtered;
   wire                               fir_dvalid;
   // TODO setting parameters like this is very error-prone since they
   // are determined based on the output of a script.
   fir_poly #(
      .N_TAPS         (120 ),
      .M              (20  ),
      .BANK_LEN       (6   ),
      .INPUT_WIDTH    (12  ),
      .TAP_WIDTH      (16  ),
      .INTERNAL_WIDTH (35  ),
      .NORM_SHIFT     (3   ),
      .OUTPUT_WIDTH   (14  )
   ) fir (
      .clk             (clk_i           ),
      .rst_n           (fir_en          ),
      .clk_2mhz_pos_en (clk_2mhz_pos_en ),
      .din             (chan_a          ),
      .dout            (chan_a_filtered ),
      .dvalid          (fir_dvalid      )
   );

   wire                               kaiser_dvalid;
   wire signed [FIR_OUTPUT_WIDTH-1:0] kaiser_out;
   window #(
      .N           (FFT_N            ),
      .DATA_WIDTH  (FIR_OUTPUT_WIDTH ),
      .COEFF_WIDTH (16               )
   ) kaiser (
      .clk    (clk_i           ),
      .rst_n  (rst_n           ),
      .en     (fir_dvalid      ),
      .clk_en (clk_2mhz_pos_en ),
      .di     (chan_a_filtered ),
      .dvalid (kaiser_dvalid   ),
      .dout   (kaiser_out      )
   );

   wire signed [FIR_OUTPUT_WIDTH-1:0] fft_in;
   wire                               fir_fft_fifo_full;
   /* verilator lint_off PINMISSING */
   async_fifo #(
      .WIDTH (FIR_OUTPUT_WIDTH ),
      .SIZE  (FFT_N            )
   ) fir_fft_fifo (
      .rst_n  (rst_n                       ),
      .full   (fir_fft_fifo_full           ),
      .rdclk  (clk_i                       ),
      .rden   (fifo_rden                   ),
      .rddata (fft_in                      ),
      .wrclk  (clk_i                       ),
      .wren   (fifo_wren & clk_2mhz_pos_en ),
      .wrdata (kaiser_out                  )
   );
   /* verilator lint_on PINMISSING */

   /* verilator lint_off WIDTH */
   localparam [$clog2(FFT_N)-1:0] FFT_N_LAST = FFT_N - 1;
   /* verilator lint_on WIDTH */

   localparam FFT_OUTPUT_WIDTH = 25;
   localparam FFT_TWIDDLE_WIDTH = 10;
   wire fft_valid;
   wire [$clog2(FFT_N)-1:0] fft_ctr;
   wire signed [FFT_OUTPUT_WIDTH-1:0] fft_re_o;
   wire signed [FFT_OUTPUT_WIDTH-1:0] fft_im_o;

   fft_r22sdf #(
      .N             (FFT_N             ),
      .INPUT_WIDTH   (FIR_OUTPUT_WIDTH  ),
      .TWIDDLE_WIDTH (FFT_TWIDDLE_WIDTH ),
      .OUTPUT_WIDTH  (FFT_OUTPUT_WIDTH  )
   ) fft (
      .clk_i      (clk_i                    ),
      .clk_3x_i   (clk_120mhz               ),
      .rst_n      (fft_en                   ),
      .sync_o     (fft_valid                ),
      .data_ctr_o (fft_ctr                  ),
      .data_re_i  (fft_in                   ),
      .data_im_i  ({FIR_OUTPUT_WIDTH{1'b0}} ),
      .data_re_o  (fft_re_o                 ),
      .data_im_o  (fft_im_o                 )
   );

   wire                               fft_ft245_fifo_full;
   reg                                fft_fifo_rden;
   reg [$clog2(FFT_N)-1:0]                  fft_ft245_ctr;
   always @(posedge clk_i) begin
      if (!rst_n) begin
         fft_fifo_rden <= 1'b0;
         fft_ft245_ctr <= {$clog2(FFT_N){1'b0}};
      end else begin
         if (fft_valid) begin
            fft_fifo_rden <= 1'b1;
            fft_ft245_ctr <= FFT_N_CMP;
         end else begin
            if (fft_ft245_ctr == 0) begin
               fft_fifo_rden <= 1'b0;
               fft_ft245_ctr <= {$clog2(FFT_N){1'b0}};
            end else if (!ft245_wrfifo_full) begin
               fft_fifo_rden <= 1'b1;
               fft_ft245_ctr <= fft_ft245_ctr - 1'b1;
            end
         end
      end
   end

   wire [FFT_OUTPUT_WIDTH+$clog2(FFT_N):0] fft_ft245_data;
   // The size is not 2*FFT_N since we read while writing.
   /* verilator lint_off PINMISSING */
   async_fifo #(
      .WIDTH (FFT_OUTPUT_WIDTH + $clog2(FFT_N) + 1 ),
      .SIZE  (FFT_N                          )
   ) fft_ft245_fifo (
      .rst_n  (rst_n                           ),
      .full   (fft_ft245_fifo_full             ),
      .rdclk  (clk_i                           ),
      .rden   (fft_fifo_rden                   ),
      .rddata (fft_ft245_data                  ),
      .wrclk  (clk_80mhz                       ),
      .wren   (fft_valid                       ),
      .wrdata ({tx_re, fft_ctr, ft245_fftdata} )
   );
   /* verilator lint_on PINMISSING */

   reg                               fft_fifo_rden_delay;
   always @(posedge clk_i) begin
      fft_fifo_rden_delay <= fft_fifo_rden;
   end

   localparam FT245_DATA_WIDTH = 38;
   wire                               ft245_wrfifo_full;
   wire                               ft245_rdfifo_full;
   wire                               ft245_rdfifo_empty;
   wire signed [7:0]                  ft245_rddata;
   wire signed [FFT_OUTPUT_WIDTH-1:0] ft245_fftdata = tx_re ? fft_re_o : fft_im_o;
   reg signed [FT245_DATA_WIDTH-1:0]  ft245_wrdata;

   wire ft245_wrfifo_empty;

   /* alternate sending FFT real and imaginary parts. */
   reg tx_re;
   always @(posedge clk_80mhz) begin
      if (!rst_n) begin
         tx_re <= 1'b0;
      end else begin
         tx_re <= ~tx_re;
      end
   end

   reg [2:0] op_state;
   localparam [2:0] IDLE = 3'b000;
   localparam [2:0] FFT = 3'b001;
   localparam [2:0] WINDOW = 3'b010;
   localparam [2:0] FIR = 3'b011;
   localparam [2:0] RAW = 3'b100;

   always @(posedge clk_80mhz) begin
      if (!rst_n) begin
         op_state <= IDLE;
      end else if (!ft245_rdfifo_empty) begin
         op_state <= ft245_rddata[2:0];
      end
   end

   reg [$clog2(FFT_N)-1:0] fir_ctr;
   always @(posedge clk_i) begin
      if (!fir_dvalid) begin
         fir_ctr <= {$clog2(FFT_N){1'b0}};
      end else if (clk_2mhz_pos_en) begin
         fir_ctr <= fir_ctr + 1'b1;
      end
   end

   reg [$clog2(FFT_N)-1:0] window_ctr;
   always @(posedge clk_i) begin
      if (!kaiser_dvalid) begin
         window_ctr <= {$clog2(FFT_N){1'b0}};
      end else if (clk_2mhz_pos_en) begin
         window_ctr <= window_ctr + 1'b1;
      end
   end

   // not enough memory for a full 20,480 length sequence
   // localparam RAW_SEQ_LEN = 20*FFT_N;
   localparam RAW_SEQ_LEN = 8000;
   localparam [$clog2(RAW_SEQ_LEN-1)-1:0] RAW_SEQ_MAX_CMP = RAW_SEQ_LEN-1;
   reg [$clog2(RAW_SEQ_LEN)-1:0] raw_ctr;
   always @(posedge clk_i) begin
      if (!fir_en) begin
         raw_ctr <= {$clog2(RAW_SEQ_LEN){1'b0}};
      end else begin
         if (raw_ctr == RAW_SEQ_MAX_CMP) begin
            raw_ctr <= {$clog2(RAW_SEQ_LEN){1'b0}};
         end else begin
            raw_ctr <= raw_ctr + 1'b1;
         end
      end
   end

   always @(*) begin
      case (op_state)
      IDLE:
        begin
           ft245_wrdata = {FT245_DATA_WIDTH{1'b0}};
           ft245_en = 1'b0;
        end
      FFT:
        begin
           ft245_wrdata = {{2{1'b0}}, fft_ft245_data};
           ft245_en = fft_fifo_rden_delay;
        end
      WINDOW:
        begin
           ft245_wrdata = {{0{1'b0}}, window_ctr, 14'd0, kaiser_out};
           ft245_en = kaiser_dvalid && clk_2mhz_pos_en;
        end
      FIR:
        begin
           ft245_wrdata = {{0{1'b0}}, fir_ctr, 14'd0, chan_a_filtered};
           ft245_en = fir_dvalid && clk_2mhz_pos_en;
        end
      RAW:
        begin
           ft245_wrdata = {{1{1'b0}}, raw_ctr, chan_b, chan_a};
           ft245_en = fir_en;
        end
      default:
        begin
           ft245_wrdata = {FT245_DATA_WIDTH{1'b0}};
           ft245_en = 1'b0;
        end
      endcase
   end

   ft245 #(
      .WRITE_DEPTH  (8192             ),
      .READ_DEPTH   (512              ),
      .DATA_WIDTH   (FT245_DATA_WIDTH ),
      .DUPLICATE_TX (1                )
   ) ft245 (
      .rst_n        (rst_n               ),
      .clk          (clk_i               ),
      .wren         (ft245_en            ),
      .wrdata       (ft245_wrdata        ),
      .wrfifo_full  (ft245_wrfifo_full   ),
      .wrfifo_empty (ft245_wrfifo_empty  ),
      .rden         (!ft245_rdfifo_empty ),
      .rddata       (ft245_rddata        ),
      .rdfifo_full  (ft245_rdfifo_full   ),
      .rdfifo_empty (ft245_rdfifo_empty  ),
      .ft_clk       (ft_clkout_i         ),
      .slow_ft_clk  (clk_7_5mhz          ),
      .rxf_n        (ft_rxf_n_i          ),
      .txe_n        (ft_txe_n_i          ),
      .rd_n         (ft_rd_n_o           ),
      .wr_n         (ft_wr_n_o           ),
      .oe_n         (ft_oe_n_o           ),
      .suspend_n    (ft_suspend_n_i      ),
      .ft_siwua_n   (ft_siwua_n_o        ),
      .ft_data      (ft_data_io          )
   );

`ifdef COCOTB_SIM
   // integer i;
   initial begin
      $dumpfile ("cocotb/build/top.vcd");
      $dumpvars (0, top);
      // for (i=0; i<100; i=i+1)
      //   $dumpvars (0, ram.mem[i]);
      #1;
   end
`endif

endmodule

`ifdef TOP_SIMULATE

`include "PLLE2_BASE.v"
`include "PLLE2_ADV.v"
`include "glbl.v"

`timescale 1ns/1ps
module top_tb;

   localparam SAMPLE_LEN = 10000;
   localparam ADC_DATA_WIDTH = 12;
   localparam USB_DATA_WIDTH = 8;

   reg signed [ADC_DATA_WIDTH-1:0] samples [0:SAMPLE_LEN-1];

   initial begin
      $dumpfile("tb/top_tb.vcd");
      $dumpvars(2, top_tb);
      $readmemh("tb/sample_in.hex", samples);

      #20000 $finish;
   end

   reg clk_40mhz = 0;
   reg clk_60mhz = 0;

   always #12.5 clk_40mhz = !clk_40mhz;
   always #8 clk_60mhz = !clk_60mhz;

   wire led;
   wire [USB_DATA_WIDTH-1:0] ft_data_io;
   wire                      ft_rd_n;
   wire                      ft_wr_n;
   wire                      ft_siwua_n;
   wire                      ft_oe_n;

   wire signed [ADC_DATA_WIDTH-1:0] sample_in = samples[ctr];
   integer                      ctr = 0;
   always @(posedge clk_40mhz) begin
      if (!dut.rst_n) begin
         ctr <= 0;
      end else begin
         if (ctr == 9999)
           ctr <= 0;
         else
           ctr <= ctr + 1;
      end
   end

   wire [1:0] adc_oe;
   wire [1:0] adc_shdn;

   wire       mix_enbl_n;
   wire       pa_en_n;

   wire       adf_ce;
   wire       adf_le;
   wire       adf_clk;
   wire       adf_txdata;
   wire       adf_data;
   wire [5:0] ext1;

   top dut (
      .clk_i          (clk_40mhz  ),
      .led_o          (led        ),
      .ext1_io        (ext1       ),

      .ft_data_io     (ft_data_io ),
      // .ft_rxf_n_i,
      .ft_txe_n_i     (1'b0       ),
      .ft_rd_n_o      (ft_rd_n    ),
      .ft_wr_n_o      (ft_wr_n    ),
      .ft_siwua_n_o   (ft_siwua_n ),
      .ft_clkout_i    (clk_60mhz  ),
      .ft_oe_n_o      (ft_oe_n    ),
      .ft_suspend_n_i (1'b1       ),

      .adc_d_i        (sample_in  ),
      // .adc_of_i,
      .adc_oe_o       (adc_oe     ),
      .adc_shdn_o     (adc_shdn   ),

      // .sd_data_i,
      // .sd_cmd_i,
      // .sd_clk_o,
      // .sd_detect_i,

      .mix_enbl_n_o   (mix_enbl_n ),

      .pa_en_n_o      (pa_en_n    ),

      .adf_ce_o       (adf_ce     ),
      .adf_le_o       (adf_le     ),
      .adf_clk_o      (adf_clk    ),
      // .adf_muxout_i,
      .adf_txdata_o   (adf_txdata ),
      .adf_data_o     (adf_data   )
      // .adf_done_i

      // .flash_cs_n_o,
      // .flash_miso_i,
      // .flash_mosi_o
   );

endmodule

`endif
