`default_nettype none

`include "parity.v"
`include "ltc2292.v"
`include "adf4158.v"
`include "ft245.v"
`include "fir_poly.v"
`include "fft_r22sdf.v"

module top #(
   parameter GPIO_WIDTH       = 6,
   parameter USB_DATA_WIDTH   = 8,
   parameter ADC_DATA_WIDTH   = 12,
   parameter SD_DATA_WIDTH    = 4,
   parameter FIR_OUTPUT_WIDTH = 14
) (
   // clocks, resets, LEDs, connectors
   input wire                             clk_i, /* 40MHz */
   output wire                            led_o,
   inout wire [GPIO_WIDTH-1:0]            ext1_io, /* General-purpose I/O. */
   inout wire [GPIO_WIDTH-1:0]            ext2_io, /* General-purpose I/O. */

`ifdef COCOTB_SIM
   input wire                             clk_7_5mhz,
   input wire                             clk_120mhz,
   input wire                             clk_20mhz,
   input wire                             pll_lock,
`endif

   // FT2232H USB interface.
   inout wire signed [USB_DATA_WIDTH-1:0] ft_data_io, /* FIFO data */
   input wire                             ft_rxf_n_i, /* Low when there is data in the buffer that can be read. */
   input wire                             ft_txe_n_i, /* Low when there is room for transmission data in the FIFO. */
   output wire                            ft_rd_n_o, /* Drive low to load read data to ft_data_io each clock cycle. */
   output wire                            ft_wr_n_o, /* Drive low to write ft_data_io to FIFO for transmission. */
   output wire                            ft_siwua_n_o, /* Flush transmission data to USB immediately. */
   input wire                             ft_clkout_i, /* 60MHz clock used to synchronize data transfers. */
   output wire                            ft_oe_n_o, /* Drive low one period before ft_rd_n_o to signal read. */
   input wire                             ft_suspend_n_i, /* Low when USB in suspend mode. */

   // ADC
   input wire signed [ADC_DATA_WIDTH-1:0] adc_d_i, /* Input data from ADC. */
   input wire [1:0]                       adc_of_i, /* High value indicates overflow or underflow. */
   output reg [1:0]                       adc_oe_o, /* 10 turns on channel A and turns off channel B. */
   output reg [1:0]                       adc_shdn_o, /* Same state as adc_oe. */

   // SD card
   // TODO: Setup option to load bitstream from SD card.
   // TODO should this be signed?
   inout wire [SD_DATA_WIDTH-1:0]         sd_data_i,
   inout wire                             sd_cmd_i,
   output reg                             sd_clk_o = 1'b0,
   input wire                             sd_detect_i,

   // mixer
   output wire                            mix_enbl_n_o, /* Low voltage enables mixer. */

   // power amplifier
   output wire                            pa_en_n_o,

   // frequency synthesizer
   output wire                            adf_ce_o,
   output wire                            adf_le_o,
   output wire                            adf_clk_o,
   input wire                             adf_muxout_i,
   output wire                            adf_txdata_o,
   output wire                            adf_data_o,
   // input wire                      adf_done_i,

   // flash memory
   // TODO: Configure flash to save bitstream configuration across boot cycles.
   output reg                             flash_cs_n_o = 1'b1,
   input wire                             flash_miso_i,
   output reg                             flash_mosi_o = 1'b0
);

   localparam FFT_N   = 1024;
   localparam N_WIDTH = $clog2(FFT_N);

   assign mix_enbl_n_o = !pll_lock;
   assign pa_en_n_o    = !pll_lock;
   assign led_o        = !pa_en_n_o;

   assign ext1_io[0] = fft_en;

   always @(posedge clk_i) begin
      if (!rst_n) begin
         adc_oe_o <= 2'b11;
         adc_shdn_o <= 2'b11;
      end else begin
         adc_oe_o <= 2'b00;
         adc_shdn_o <= 2'b00;
      end
   end

   // TODO not portable
   reg pwr_on_rst_n = 1'b0;
   always @(posedge clk_i) begin
      if (!rst_n && !pwr_on_rst_n) begin
         pwr_on_rst_n <= 1'b0;
      end else begin
         pwr_on_rst_n <= 1'b1;
      end
   end

`ifndef COCOTB_SIM
   /**
    * Drives onboard logic.
    */
   wire                            clk_120mhz;
   wire                            clk_20mhz;
   wire                            pll_lock;
   wire                            pll_fb;
   /* verilator lint_off DECLFILENAME */
   PLLE2_BASE #(
      .CLKFBOUT_MULT  (24 ),
      .DIVCLK_DIVIDE  (1  ),
      .CLKOUT0_DIVIDE (8  ),
      .CLKOUT1_DIVIDE (48 ),
      .CLKIN1_PERIOD  (25 )
   ) main_pll (
      .CLKOUT0  (clk_120mhz ),
      .CLKOUT1  (clk_20mhz  ),
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

   wire                            adf_config_done;
   adf4158 adf4158 (
      .clk         (clk_i           ),
      .clk_20mhz   (clk_20mhz       ),
      .rst_n       (pll_lock        ),
      .enable      (pll_lock        ),
      .config_done (adf_config_done ),
      .le          (adf_le_o        ),
      .ce          (adf_ce_o        ),
      .muxout      (adf_muxout_i    ),
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
      .rst_n           (adf_config_done ),
      .clk_2mhz_pos_en (clk_2mhz_pos_en ),
      .din             (chan_a          ),
      .dout            (chan_a_filtered ),
      .dvalid          (fir_dvalid      )
   );

   reg [N_WIDTH-1:0]                  fir_ctr;
   always @(posedge clk_i) begin
      if (!rst_n) begin
         fir_ctr <= {N_WIDTH{1'b0}};
      end else begin
         if (fir_dvalid && clk_2mhz_pos_en) begin
            fir_ctr <= fir_ctr + 1'b1;
         end
      end
   end

   wire signed [FIR_OUTPUT_WIDTH-1:0] fft_in;
   wire                               fir_fft_fifo_full;
   async_fifo #(
      .WIDTH (FIR_OUTPUT_WIDTH ),
      .SIZE  (FFT_N            )
   ) fir_fft_fifo (
      .rst_n  (pwr_on_rst_n                 ),
      .full   (fir_fft_fifo_full            ),
      .rdclk  (clk_i                        ),
      .rden   (fft_rd_en                    ),
      .rddata (fft_in                       ),
      .wrclk  (clk_i                        ),
      .wren   (fir_dvalid & clk_2mhz_pos_en ),
      .wrdata (chan_a_filtered              )
   );

   reg               fft_en;
   // reg [N_WIDTH-1:0] fft_bit_normal_ctr;
   // always @(posedge clk_i) begin
   //    if (fft_en) begin
   //       fft_bit_normal_ctr <= fft_bit_normal_ctr + 1'b1;
   //    end else begin
   //       fft_bit_normal_ctr <= {N_WIDTH{1'b0}};
   //    end
   // end

   /* verilator lint_off WIDTH */
   localparam [N_WIDTH-1:0] FFT_N_LAST = FFT_N - 1;
   /* verilator lint_on WIDTH */

   // must wait 1 clock after asserting read enable to get data from
   // fifo.
   reg               fft_rd_en;
   always @(posedge clk_i) begin
      if (!rst_n) begin
         fft_en <= 1'b0;
         fft_rd_en <= 1'b0;
      end else begin
         if (fir_fft_fifo_full || fft_en) begin
            if (fft_ctr == FFT_N_LAST) begin
               fft_rd_en <= 1'b0;
               fft_en <= 1'b0;
            end else begin
               if (fft_rd_en) begin
                  fft_en <= 1'b1;
                  fft_rd_en <= 1'b1;
               end else begin
                  fft_en <= 1'b0;
                  fft_rd_en <= 1'b1;
               end
            end
         end else begin
            fft_rd_en <= 1'b0;
            fft_en <= 1'b0;
         end

         // if (fft_ctr == FFT_N_LAST-1) begin
         //    fft_en <= 1'b0;
         // end else if (fir_ctr == FFT_N_LAST-1 || fft_en) begin
         //    fft_en <= 1'b1;
         // end
      end
   end

   localparam FFT_OUTPUT_WIDTH = 25;
   wire fft_valid;
   wire [N_WIDTH-1:0] fft_ctr;
   wire signed [FFT_OUTPUT_WIDTH-1:0] fft_re_o;
   wire signed [FFT_OUTPUT_WIDTH-1:0] fft_im_o;
   fft_r22sdf #(
      .N             (FFT_N            ),
      .INPUT_WIDTH   (FIR_OUTPUT_WIDTH ),
      .TWIDDLE_WIDTH (10               ),
      .OUTPUT_WIDTH  (FFT_OUTPUT_WIDTH )
   ) fft (
      .clk_i      (clk_i                    ),
      .clk_3x_i   (clk_120mhz               ),
      .rst_n      (pwr_on_rst_n             ),
      .sync_o     (fft_valid                ),
      .data_ctr_o (fft_ctr                  ),
      .data_re_i  (fft_in                   ),
      .data_im_i  ({FIR_OUTPUT_WIDTH{1'b0}} ),
      .data_re_o  (fft_re_o                 ),
      .data_im_o  (fft_im_o                 )
   );

   localparam FT245_DATA_WIDTH = 64;
   wire                               ft245_wrfifo_full;
   wire                               ft245_rdfifo_full;
   wire                               ft245_rdfifo_empty;
   wire signed [7:0]                  ft245_rddata;
   wire signed [2*FFT_OUTPUT_WIDTH-1:0] ft245_wrdata = {fft_im_o, fft_re_o};
   wire                               parity_bit;
   parity #(
      .DATA_WIDTH (2*FFT_OUTPUT_WIDTH)
   ) parity (
      .di  (ft245_wrdata ),
      .par (parity_bit   )
   );

   ft245 #(
      .WRITE_DEPTH  (1024             ),
      .READ_DEPTH   (512              ),
      .DATA_WIDTH   (FT245_DATA_WIDTH ),
      .DUPLICATE_TX (1                )
   ) ft245 (
      .rst_n        (rst_n                                              ),
      .clk          (clk_i                                              ),
      .wren         (!ft245_wrfifo_full && fft_valid                    ),
      .wrdata       ({4'h8, parity_bit, {5{1'b0}}, ft245_wrdata, 4'h0}  ),
      .wrfifo_full  (ft245_wrfifo_full                                  ),
      .rden         (!ft245_rdfifo_empty                                ),
      .rddata       (ft245_rddata                                       ),
      .rdfifo_full  (ft245_rdfifo_full                                  ),
      .rdfifo_empty (ft245_rdfifo_empty                                 ),
      .ft_clk       (ft_clkout_i                                        ),
      .slow_ft_clk  (clk_7_5mhz                                         ),
      .rxf_n        (ft_rxf_n_i                                         ),
      .txe_n        (ft_txe_n_i                                         ),
      .rd_n         (ft_rd_n_o                                          ),
      .wr_n         (ft_wr_n_o                                          ),
      .oe_n         (ft_oe_n_o                                          ),
      .suspend_n    (ft_suspend_n_i                                     ),
      .ft_siwua_n   (ft_siwua_n_o                                       ),
      .ft_data      (ft_data_io                                         )
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
