`default_nettype none

`include "adc.v"
`include "fir_poly.v"
`include "fft_r22sdf.v"
`include "ram_tdp_18k.v"
`include "adf4158.v"

module top #(
   parameter GPIO_WIDTH       = 6,
   parameter USB_DATA_WIDTH   = 8,
   parameter ADC_DATA_WIDTH   = 12,
   parameter SD_DATA_WIDTH    = 4,
   parameter FIR_OUTPUT_WIDTH = 14
) (
   // clocks, resets, LEDs, connectors
   input wire                      clk_i, /* 40MHz */
   output wire                     led_o,
   inout wire [GPIO_WIDTH-1:0]     ext1_io, /* General-purpose I/O. */
   inout wire [GPIO_WIDTH-1:0]     ext2_io, /* General-purpose I/O. */

   // FT2232H USB interface.
   inout wire [USB_DATA_WIDTH-1:0] ft_data_io, /* FIFO data */
   input wire                      ft_rxf_n_i, /* Low when there is data in the buffer that can be read. */
   input wire                      ft_txe_n_i, /* Low when there is room for transmission data in the FIFO. */
   output wire                     ft_rd_n_o, /* Drive low to load read data to ft_data_io each clock cycle. */
   output reg                      ft_wr_n_o, /* Drive low to write ft_data_io to FIFO for transmission. */
   output wire                     ft_siwua_n_o, /* Flush transmission data to USB immediately. */
   input wire                      ft_clkout_i, /* 60MHz clock used to synchronize data transfers. */
   output wire                     ft_oe_n_o, /* Drive low one period before ft_rd_n_o to signal read. */
   input wire                      ft_suspend_n_i, /* Low when USB in suspend mode. */

   // ADC
   input wire [ADC_DATA_WIDTH-1:0] adc_d_i, /* Input data from ADC. */
   input wire [1:0]                adc_of_i, /* High value indicates overflow or underflow. */
   output reg [1:0]                adc_oe_o = 2'b00, /* 10 turns on channel A and turns off channel B. */
   output reg [1:0]                adc_shdn_o = 2'b00, /* Same state as adc_oe. */

   // SD card
   // TODO: Setup option to load bitstream from SD card.
   inout wire [SD_DATA_WIDTH-1:0]  sd_data_i,
   inout wire                      sd_cmd_i,
   output reg                      sd_clk_o,
   input wire                      sd_detect_i,

   // mixer
   output reg                      mix_enbl_n_o = 1'b0, /* Low voltage enables mixer. */

   // power amplifier
   output reg                      pa_en_n_o = 1'b0,

   // frequency synthesizer
   output wire                     adf_ce_o,
   output wire                     adf_le_o,
   output wire                     adf_clk_o,
   input wire                      adf_muxout_i,
   output wire                     adf_txdata_o,
   output wire                     adf_data_o,
   // input wire                      adf_done_i,

   // flash memory
   // TODO: Configure flash to save bitstream configuration across boot cycles.
   output reg                      flash_cs_n_o,
   input wire                      flash_miso_i,
   output reg                      flash_mosi_o
);

   localparam FFT_N   = 1024;
   localparam N_WIDTH = $clog2(FFT_N);

   wire                            clk_120mhz;
   wire                            clk_20mhz;
   wire                            pll_lock;
   wire                            pll_fb;

   wire                            rst_n = pll_lock;

   // assign mix_enbl_n_o = !pll_lock;
   // assign pa_en_n_o    = !pll_lock;
   assign led_o        = !pa_en_n_o;

   assign ext1_io[0] = ft_wr_n_o;
   assign ext1_io[1] = clk_7_5mhz;
   assign ext1_io[2] = clk_22_5mhz;
   assign ext1_io[3] = fft_en;
   assign ext1_io[4] = start;
   assign ext1_io[5] = fft_valid;

   // always @(posedge clk_i) begin
   //    if (!rst_n) begin
   //       adc_oe_o <= 2'b11;
   //       adc_shdn_o <= 2'b11;
   //    end else begin
   //       adc_oe_o <= 2'b10;
   //       adc_shdn_o <= 2'b10;
   //    end
   // end

   wire                            clk_7_5mhz;
   wire                            clk_22_5mhz;

   MMCME2_BASE #(
     .CLKFBOUT_MULT_F  (22.5),
     .CLKIN1_PERIOD    (25),
     .DIVCLK_DIVIDE    (1),
     .CLKOUT0_DIVIDE_F (7.5),
     .CLKOUT1_DIVIDE   (45),
     .CLKOUT2_DIVIDE   (120),
     .CLKOUT3_DIVIDE   (40)
   ) pll (
     .CLKIN1   (clk_i),
     .RST      (1'b0),
     .PWRDWN   (1'b0),
     .LOCKED   (pll_lock),
     .CLKFBIN  (pll_fb),
     .CLKFBOUT (pll_fb),
     .CLKOUT0  (clk_120mhz),
     .CLKOUT1  (clk_20mhz),
     .CLKOUT2  (clk_7_5mhz),
     .CLKOUT3  (clk_22_5mhz)
   );

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
      .clk         (clk_i),
      .clk_20mhz   (clk_20mhz),
      .rst_n       (pll_lock),
      .enable      (pll_lock),
      .config_done (adf_config_done),

      .ce          (adf_ce_o),
      .muxout      (adf_muxout_i),
      .txdata      (adf_txdata_o),
      .data        (adf_data_o)
   );

   wire signed [ADC_DATA_WIDTH-1:0] chan_a;

   adc #(
      .DATA_WIDTH (ADC_DATA_WIDTH)
   ) adc (
      .clk_i   (clk_i),
      .ce_i    (adf_config_done),
      .data_i  (adc_d_i),
      .chan_a  (chan_a)
   );

   wire signed [FIR_OUTPUT_WIDTH-1:0] chan_a_filtered;
   wire                               fir_dvalid;

   fir_poly #(
      .N_TAPS         (120),
      .M              (20),
      .BANK_LEN       (6),
      .INPUT_WIDTH    (12),
      .TAP_WIDTH      (16),
      .INTERNAL_WIDTH (35),
      .NORM_SHIFT     (4),
      .OUTPUT_WIDTH   (14)
   ) fir (
      .clk             (clk_i),
      .rst_n           (adf_config_done),
      .clk_2mhz_pos_en (clk_2mhz_pos_en),
      .din             (chan_a),
      .dout            (chan_a_filtered),
      .dvalid          (fir_dvalid)
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
   ram_tdp_18k #(
      .ADDRESS_WIDTH (N_WIDTH),
      .DATA_WIDTH    (FIR_OUTPUT_WIDTH)
   ) ram (
      .clk1  (clk_i),
      .clk2  (clk_7_5mhz),
      .en1   (clk_2mhz_pos_en),
      .en2   (fft_en),
      .we1   (1'b1),
      .we2   (1'b0),
      .addr1 (fir_ctr),
      .addr2 (fft_bit_normal_ctr),
      .di1   (chan_a_filtered),
      .do2   (fft_in)
   );

   reg               fft_en;
   reg [N_WIDTH-1:0] fft_bit_normal_ctr;
   always @(posedge clk_7_5mhz) begin
      if (fft_en) begin
         fft_bit_normal_ctr <= fft_bit_normal_ctr + 1'b1;
      end else begin
         fft_bit_normal_ctr <= {N_WIDTH{1'b0}};
      end
   end

   (* ASYNC_REG = "TRUE" *) reg [N_WIDTH-1:0] fir_ctr_cdc;
   (* ASYNC_REG = "TRUE" *) reg [N_WIDTH-1:0] fir_ctr_stbl;
   always @(posedge clk_7_5mhz) begin
      if (!rst_n) begin
         fft_en       <= 1'b0;
         fir_ctr_cdc  <= {N_WIDTH{1'b0}};
         fir_ctr_stbl <= {N_WIDTH{1'b0}};
      end else begin
         {fir_ctr_stbl, fir_ctr_cdc} <= {fir_ctr_cdc, fir_ctr};
         if (fft_ctr == FFT_N-1) begin
            fft_en  <= 1'b0;
         end else if (fir_ctr_stbl == FFT_N-3 || fft_en) begin
            fft_en  <= 1'b1;
         end
      end
   end

   localparam FFT_OUTPUT_WIDTH = 25;

   wire fft_valid;
   wire [N_WIDTH-1:0] fft_ctr;
   wire signed [FFT_OUTPUT_WIDTH-1:0] fft_re_o;
   wire signed [FFT_OUTPUT_WIDTH-1:0] fft_im_o;

   fft_r22sdf #(
      .N             (1024),
      .INPUT_WIDTH   (14),
      .TWIDDLE_WIDTH (10),
      .OUTPUT_WIDTH  (FFT_OUTPUT_WIDTH)
   ) fft (
      .clk_i      (clk_7_5mhz),
      .clk_3x_i   (clk_22_5mhz),
      .rst_n      (fft_en),
      .sync_o     (fft_valid),
      .data_ctr_o (fft_ctr),
      .data_re_i  (fft_in),
      .data_im_i  ({FIR_OUTPUT_WIDTH{1'b0}}),
      .data_re_o  (fft_re_o),
      .data_im_o  (fft_im_o)
   );

   // usb
   // Data is transmitted to the host PC in packets of 8 bytes.
   reg                         start;
   always @(posedge clk_7_5mhz) begin
      if (!rst_n) begin
         start <= 1'b0;
      end else begin
         start <= 1'b1;
      end
   end

   reg [2:0]                   tx_byte_ctr;
   reg [USB_DATA_WIDTH-1:0]    ft_data;
   assign ft_data_io = !ft_wr_n_o ? ft_data : 1'bz;


   (* ASYNC_REG = "TRUE" *) reg [N_WIDTH-1:0]           fft_ctr_cdc;
   (* ASYNC_REG = "TRUE" *) reg signed [FFT_OUTPUT_WIDTH-1:0] fft_re_cdc;
   (* ASYNC_REG = "TRUE" *) reg signed [FFT_OUTPUT_WIDTH-1:0] fft_im_cdc;

   always @(negedge ft_clkout_i) begin
      if (!rst_n) begin
         tx_byte_ctr <= 3'd0;
         ft_wr_n_o   <= 1'b1;
      end else begin
         ft_wr_n_o <= 1'b0;
         if (start) begin
            tx_byte_ctr <= tx_byte_ctr + 1'b1;
         end

         fft_ctr_cdc <= fft_ctr;
         fft_re_cdc <= fft_re_o;
         fft_im_cdc <= fft_im_o;

         if (fft_valid) begin
            case (tx_byte_ctr)
            3'd0: ft_data <= {4'hf, fft_ctr_cdc[9:6]};
            3'd1: ft_data <= {fft_ctr_cdc[5:0], fft_re_cdc[24:23]};
            3'd2: ft_data <= fft_re_cdc[22:15];
            3'd3: ft_data <= fft_re_cdc[14:7];
            3'd4: ft_data <= {fft_re_cdc[6:0], fft_im_cdc[24:24]};
            3'd5: ft_data <= fft_im_cdc[23:16];
            3'd6: ft_data <= fft_im_cdc[15:8];
            3'd7: ft_data <= fft_im_cdc[7:0];
            endcase
         end else begin
            ft_data <= {USB_DATA_WIDTH{1'b0}};
         end
      end
   end

endmodule

`ifdef TOP_SIMULATE

`include "MMCME2_BASE.v"
`include "MMCME2_ADV.v"
`include "BRAM_SINGLE_MACRO.v"
`include "BRAM_SDP_MACRO.v"
`include "BRAM_TDP_MACRO.v"
`include "RAMB18E1.v"
`include "DSP48E1.v"
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
      .clk_i          (clk_40mhz),
      .led_o          (led),
      .ext1_io        (ext1),

      .ft_data_io     (ft_data_io),
      // .ft_rxf_n_i,
      // .ft_txe_n_i,
      .ft_rd_n_o      (ft_rd_n),
      .ft_wr_n_o      (ft_wr_n),
      .ft_siwua_n_o   (ft_siwua_n),
      .ft_clkout_i    (clk_60mhz),
      .ft_oe_n_o      (ft_oe_n),
      .ft_suspend_n_i (1'b1),

      .adc_d_i        (sample_in),
      // .adc_of_i,
      .adc_oe_o       (adc_oe),
      .adc_shdn_o     (adc_shdn),

      // .sd_data_i,
      // .sd_cmd_i,
      // .sd_clk_o,
      // .sd_detect_i,

      .mix_enbl_n_o   (mix_enbl_n),

      .pa_en_n_o      (pa_en_n),

      .adf_ce_o       (adf_ce),
      .adf_le_o       (adf_le),
      .adf_clk_o      (adf_clk),
      // .adf_muxout_i,
      .adf_txdata_o   (adf_txdata),
      .adf_data_o     (adf_data)
      // .adf_done_i

      // .flash_cs_n_o,
      // .flash_miso_i,
      // .flash_mosi_o
   );

endmodule

`endif
