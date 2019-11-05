`default_nettype none

`include "fmcw_defines.vh"
`include "adf4158/adf4158.v"
`include "fir/fir.v"
`include "fir/fir_poly.v"
`include "fir/rom.v"
`include "fft/fft_r22sdf.v"
`include "adc/adc.v"
`include "usb/usb.v"
`include "dsp/dsp.v"

module top #(
   `FMCW_PARAMS
) (
   // clocks, resets, LEDs, connectors
   input wire                      clk_i, /* 40MHz */
   output wire                     led_o, /* Indicates packet sent between PC and FPGA. */
   inout wire [GPIO_WIDTH-1:0]     ext1_io, /* General-purpose I/O. */
   inout wire [GPIO_WIDTH-1:0]     ext2_io, /* General-purpose I/O. */

   // FT2232H USB interface.
   inout wire [USB_DATA_WIDTH-1:0] ft_data_io, /* FIFO data */
   input wire                      ft_rxf_n_i, /* Low when there is data in the buffer that can be read. */
   input wire                      ft_txe_n_i, /* Low when there is room for transmission data in the FIFO. */
   output wire                     ft_rd_n_o, /* Drive low to load read data to ft_data_io each clock cycle. */
   output wire                     ft_wr_n_o, /* Drive low to write ft_data_io to FIFO for transmission. */
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
   output reg                      sd_clk_o = 1'b0,
   input wire                      sd_detect_i,

   // mixer
   output reg                      mix_enbl_n_o = 1'b0, /* Low voltage enables mixer. */

   // power amplifier
   output wire                     pa_en_n_o,

   // frequency synthesizer
   output wire                     adf_ce_o,
   output wire                     adf_le_o,
   output wire                     adf_clk_o,
   input wire                      adf_muxout_i,
   output wire                     adf_txdata_o,
   output wire                     adf_data_o,
   input wire                      adf_done_i,

   // flash memory
   // TODO: Configure flash to save bitstream configuration across boot cycles.
   output reg                      flash_cs_n_o = 1'b1,
   input wire                      flash_miso_i,
   output reg                      flash_mosi_o = 1'b0
);

   function [FFT_ANGLE_INPUT_WIDTH-1:0] trunc_fft(input [FFT_DIST_OUTPUT_WIDTH-1:0] expr);
      trunc_fft = expr[FFT_ANGLE_INPUT_WIDTH-1:0];
   endfunction // trunc_fft

   // Generate 120MHz, 320MHz and 20MHz clocks. The 120MHz clock is
   // used to time-multiplex DSP slices in the FIR and FFT modules,
   // the 320MHz clock is to feed data from a RAM module to an FFT for
   // the angle calculation, and the 20MHz clock is used to
   // synchronize data writes to the frequency synthesizer.
   wire                            clk_120mhz;
   wire                            clk_20mhz;
   wire                            clk_10mhz;
   wire                            clk_30mhz;
   wire                            pll_lock;
   wire                            clk_fb;

   PLLE2_BASE #(
      .CLKFBOUT_MULT  (24),
      .DIVCLK_DIVIDE  (1),
      .CLKOUT0_DIVIDE (8),
      .CLKOUT1_DIVIDE (48),
      .CLKOUT2_DIVIDE (96),
      .CLKOUT3_DIVIDE (32),
      .CLKIN1_PERIOD  (25)
   ) pll (
      .CLKOUT0  (clk_120mhz),
      .CLKOUT1  (clk_20mhz),
      .CLKOUT2  (clk_10mhz),
      .CLKOUT3  (clk_30mhz),
      .LOCKED   (pll_lock),
      .CLKIN1   (clk_i),
      .RST      (1'b0),
      .CLKFBOUT (clk_fb),
      .CLKFBIN  (clk_fb)
   );

   // use a global ce to hold the design in an initial state when the
   // PLLs aren't locked.
   wire                            ce = pll_lock;

   // Generate 2MHz and 4MHz clock enables.
   reg                             clk_2mhz_pos_en = 1'b1;
   reg                             clk_2mhz_neg_en = 1'b1;
   reg [4:0]                       clk_2mhz_ctr    = 5'd0;
   reg                             clk_4mhz_pos_en = 1'b1;
   reg [3:0]                       clk_4mhz_ctr    = 5'd0;

   always @(posedge clk_i) begin
      if (clk_4mhz_ctr == 4'd9) begin
         clk_4mhz_pos_en <= 1'b1;
         clk_4mhz_ctr    <= 4'd0;
      end else begin
         clk_4mhz_pos_en <= 1'b0;
         clk_4mhz_ctr    <= clk_4mhz_ctr + 1'b1;
      end

      if (clk_2mhz_ctr == 5'd9) begin
         clk_2mhz_neg_en <= 1'b1;
         clk_2mhz_pos_en <= 1'b0;
         clk_2mhz_ctr    <= clk_2mhz_ctr + 1'b1;
      end else if (clk_2mhz_ctr == 5'd19) begin
         clk_2mhz_neg_en <= 1'b0;
         clk_2mhz_pos_en <= 1'b1;
         clk_2mhz_ctr    <= 5'd0;
      end else begin
         clk_2mhz_neg_en <= 1'b0;
         clk_2mhz_pos_en <= 1'b0;
         clk_2mhz_ctr    <= clk_2mhz_ctr + 1'b1;
      end
   end

   assign ext1_io[0] = ft_wr_n_o;
   assign ext1_io[1] = ft_rd_n_o;
   assign ext1_io[2] = ft_clkout_i;
   assign ext1_io[3] = ft_suspend_n_i;
   assign ext1_io[4] = adf_muxout_i;
   assign ext1_io[5] = 1'b1;

   assign ext2_io[0] = ft_wr_n_o;
   assign ext2_io[1] = ft_rd_n_o;
   assign ext2_io[2] = ft_clkout_i;
   assign ext2_io[3] = ft_suspend_n_i;
   assign ext2_io[4] = 1'b0;
   assign ext2_io[5] = 1'b1;
   // assign ext1_io = {GPIO_WIDTH{1'b0}};
   // assign ext2_io = {GPIO_WIDTH{1'b0}};
   assign led_o = (!ft_rd_n_o || !ft_wr_n_o) ? 1'b1 : 1'b0;

   wire [ADC_DATA_WIDTH-1:0]           chan_a;
   wire [ADC_DATA_WIDTH-1:0]           chan_b;
   wire [FIR_OUTPUT_WIDTH-1:0]         chan_a_filtered;
   wire [FIR_OUTPUT_WIDTH-1:0]         chan_b_filtered;

   // FSM
   reg                                 adf_config_enable   = 1'b1;
   reg                                 adf_soft_enable     = 1'b0;
   reg                                 adf_soft_disable    = 1'b0;
   reg                                 sample_delay_enable = 1'b0;
   reg [1:0]                           sample_delay_ctr    = 2'd0;
   reg                                 sample_enable       = 1'b0;
   reg [14:0]                          sample_ctr          = 15'd0;
   reg [2:0]                           sweep_ctr           = 3'd0;
   reg                                 sample_done         = 1'b0;
   reg                                 fft_dist_enable     = 1'b0;
   reg                                 fft_dist_done       = 1'b0;
   reg                                 fft_angle_enable    = 1'b0;

   always @(posedge clk_i) begin
      if (ce) begin
         if (adf_config_enable) begin
            adf_soft_disable    <= 1'b0;
            sample_enable       <= 1'b0;
            sample_delay_enable <= 1'b0;
            sample_ctr          <= 15'd0;
            sample_done         <= 1'b0;
            fft_dist_enable     <= 1'b0;
            fft_angle_enable    <= 1'b0;
            if (adf_config_done) begin
               adf_config_enable <= 1'b0;
               adf_soft_enable   <= 1'b1;
            end else begin
               adf_config_enable <= 1'b1;
               adf_soft_enable   <= 1'b0;
            end
         end else if (adf_soft_enable) begin
            adf_config_enable   <= 1'b0;
            adf_soft_disable    <= 1'b0;
            sample_enable       <= 1'b0;
            sample_ctr          <= 15'd0;
            sample_done         <= 1'b0;
            fft_dist_enable     <= 1'b0;
            fft_angle_enable    <= 1'b0;
            if (adf_config_done) begin
               adf_soft_enable     <= 1'b0;
               sample_delay_enable <= 1'b1;
            end else begin
               adf_soft_enable     <= 1'b1;
               sample_delay_enable <= 1'b0;
            end
         end else if (sample_delay_enable) begin // if (adf_soft_enable)
            adf_config_enable   <= 1'b0;
            adf_soft_disable    <= 1'b0;
            sample_ctr          <= 15'd0;
            sample_done         <= 1'b0;
            fft_dist_enable     <= 1'b0;
            fft_angle_enable    <= 1'b0;
            if (sample_delay_ctr == 2'd3) begin
               sample_delay_enable <= 1'b0;
               sample_enable       <= 1'b1;
               sample_delay_ctr    <= 2'd0;
            end else begin
               sample_delay_enable <= 1'b1;
               sample_enable       <= 1'b0;
               sample_delay_ctr    <= sample_delay_ctr + 2'd1;
            end
         end else if (sample_enable) begin // if (adf_soft_enable)
            adf_config_enable   <= 1'b0;
            adf_soft_enable     <= 1'b0;
            adf_soft_disable    <= 1'b0;
            sample_delay_enable <= 1'b0;
            sample_done         <= 1'b1;
            fft_dist_enable     <= 1'b0;
            fft_angle_enable    <= 1'b0;
            // 20,479 comes from 1024 samples * 40MHz/2MHz
            if (sample_ctr == 15'd20479) begin
               sample_ctr <= 15'd0;
               if (sweep_ctr == 3'd7) begin
                  sample_enable <= 1'b0;
                  sample_done   <= 1'b1;
                  sweep_ctr     <= 3'd0;
               end else begin
                  sample_enable <= 1'b1;
                  sample_done   <= 1'b0;
                  sweep_ctr     <= sweep_ctr + 1'b1;
               end
            end else begin
               sample_enable <= 1'b1;
               sample_ctr    <= sample_ctr + 15'd1;
               sweep_ctr     <= sweep_ctr;
            end
         end else if (sample_done) begin // if (sample_enable)
            adf_config_enable   <= 1'b0;
            adf_soft_enable     <= 1'b0;
            adf_soft_disable    <= 1'b1;
            sample_delay_enable <= 1'b0;
            sample_enable       <= 1'b0;
            sample_ctr          <= 15'd0;
            sample_done         <= 1'b0;
            fft_dist_enable     <= 1'b0;
            fft_angle_enable    <= 1'b0;
         end else if (adf_soft_disable) begin
            adf_config_enable   <= 1'b0;
            adf_soft_enable     <= 1'b0;
            sample_delay_enable <= 1'b0;
            sample_enable       <= 1'b0;
            sample_ctr          <= 15'd0;
            sample_done         <= 1'b0;
            fft_angle_enable    <= 1'b0;
            if (adf_config_done) begin
               adf_soft_disable <= 1'b0;
               fft_dist_enable  <= 1'b1;
            end else begin
               adf_soft_disable <= 1'b1;
               fft_dist_enable  <= 1'b0;
            end
         end else if (fft_dist_enable) begin // if (adf_soft_disable)
            adf_config_enable   <= 1'b0;
            adf_soft_enable     <= 1'b0;
            adf_soft_disable    <= 1'b0;
            sample_delay_enable <= 1'b0;
            sample_enable       <= 1'b0;
            sample_ctr          <= 15'd0;
            sample_done         <= 1'b0;
            if (fft_dist_done) begin
               fft_dist_enable  <= 1'b0;
               fft_angle_enable <= 1'b1;
            end else begin
               fft_dist_enable  <= 1'b1;
               fft_angle_enable <= 1'b0;
            end
         end else if (fft_angle_enable) begin
            adf_config_enable   <= 1'b0;
            adf_soft_disable    <= 1'b0;
            sample_delay_enable <= 1'b0;
            sample_enable       <= 1'b0;
            sample_ctr          <= 15'd0;
            sample_done         <= 1'b0;
            fft_dist_enable     <= 1'b0;
            if (fft_angle_done) begin
               adf_soft_enable  <= 1'b1;
               fft_angle_enable <= 1'b0;
            end else begin
               adf_soft_enable  <= 1'b0;
               fft_angle_enable <= 1'b1;
            end
         end
      end else begin
         adf_config_enable   <= 1'b1;
         adf_soft_enable     <= 1'b0;
         adf_soft_disable    <= 1'b0;
         sample_delay_enable <= 1'b0;
         sample_enable       <= 1'b0;
         sample_ctr          <= 15'd0;
         sample_done         <= 1'b0;
         fft_dist_enable     <= 1'b0;
         fft_angle_enable    <= 1'b0;
      end
   end

   // The power amplifier uses a lot of energy and generates a lot of
   // heat. We only want it enabled when the frequency synthesizer is
   // ramping.
   assign pa_en_n_o = !(sample_enable || sample_delay_enable);

   reg adf_soft_enable = 1'b1;
   wire adf_config_done;

   adf4158 adf4158 (
      .clk_i         (clk_i),
      .clk_20mhz_i   (clk_20mhz),
      .ce_i          (adf_soft_enable),
      .config_done_o (adf_config_done),
      .le_o          (adf_le_o),
      .txdata_o      (adf_txdata_o),
      .data_o        (adf_data_o)
   );
   assign adf_clk_o = clk_20mhz;

   adc #(
      .DATA_WIDTH (ADC_DATA_WIDTH)
   ) adc (
      .clk_i  (clk_i),
      .ce_i   (sample_enable),
      .data_i (adc_d_i),
      .chan_a (chan_a),
      .chan_b (chan_b)
   );

   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f0  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f1  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f2  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f3  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f4  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f5  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f6  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f7  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f8  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f9  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f10 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f11 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f12 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f13 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f14 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f15 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f16 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f17 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f18 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_a_f19 = {FIR_INTERNAL_WIDTH{1'b0}};

   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f0  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f1  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f2  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f3  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f4  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f5  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f6  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f7  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f8  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f9  = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f10 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f11 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f12 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f13 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f14 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f15 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f16 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f17 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f18 = {FIR_INTERNAL_WIDTH{1'b0}};
   reg signed [FIR_INTERNAL_WIDTH-1:0] fir_chan_b_f19 = {FIR_INTERNAL_WIDTH{1'b0}};

   wire [FIR_POLY_BANK_LEN_LOG2-1:0]   fir_tap_addr;

   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap0;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap1;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap2;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap3;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap4;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap5;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap6;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap7;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap8;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap9;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap10;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap11;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap12;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap13;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap14;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap15;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap16;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap17;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap18;
   wire signed [FIR_TAP_WIDTH-1:0]     fir_tap19;

   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_0;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_1;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_2;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_3;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_4;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_5;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_6;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_7;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_8;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_9;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_10;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_11;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_12;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_13;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_14;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_15;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_16;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_17;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_18;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_a_d_2mhz_19;

   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_0;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_1;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_2;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_3;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_4;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_5;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_6;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_7;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_8;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_9;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_10;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_11;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_12;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_13;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_14;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_15;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_16;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_17;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_18;
   wire signed [FIR_OUTPUT_WIDTH-1:0]  fir_chan_b_d_2mhz_19;

   fir #(
      .M                  (FIR_M),
      .M_WIDTH            (FIR_M_WIDTH),
      .INPUT_WIDTH        (ADC_DATA_WIDTH),
      .INTERNAL_WIDTH     (FIR_INTERNAL_WIDTH),
      .NORM_SHIFT         (FIR_NORM_SHIFT),
      .OUTPUT_WIDTH       (FIR_OUTPUT_WIDTH),
      .TAP_WIDTH          (FIR_TAP_WIDTH),
      .POLY_BANK_LEN      (FIR_POLY_BANK_LEN),
      .POLY_BANK_LEN_LOG2 (FIR_POLY_BANK_LEN_LOG2),
      .ROM_SIZE           (FIR_ROM_SIZE)
   ) fir (
      .clk_i             (clk_i),
      .clk_120mhz_i      (clk_120mhz),
      .clk_2mhz_pos_en_i (clk_2mhz_pos_en),
      .ce_i              (sample_enable),
      .chan_a_di_i       (chan_a),
      .chan_b_di_i       (chan_b),
      .chan_a_do_o       (chan_a_filtered),
      .chan_b_do_o       (chan_b_filtered),
      .chan_a_f0         (fir_chan_a_f0),
      .chan_a_f1         (fir_chan_a_f1),
      .chan_a_f2         (fir_chan_a_f2),
      .chan_a_f3         (fir_chan_a_f3),
      .chan_a_f4         (fir_chan_a_f4),
      .chan_a_f5         (fir_chan_a_f5),
      .chan_a_f6         (fir_chan_a_f6),
      .chan_a_f7         (fir_chan_a_f7),
      .chan_a_f8         (fir_chan_a_f8),
      .chan_a_f9         (fir_chan_a_f9),
      .chan_a_f10        (fir_chan_a_f10),
      .chan_a_f11        (fir_chan_a_f11),
      .chan_a_f12        (fir_chan_a_f12),
      .chan_a_f13        (fir_chan_a_f13),
      .chan_a_f14        (fir_chan_a_f14),
      .chan_a_f15        (fir_chan_a_f15),
      .chan_a_f16        (fir_chan_a_f16),
      .chan_a_f17        (fir_chan_a_f17),
      .chan_a_f18        (fir_chan_a_f18),
      .chan_a_f19        (fir_chan_a_f19),
      .chan_b_f0         (fir_chan_b_f0),
      .chan_b_f1         (fir_chan_b_f1),
      .chan_b_f2         (fir_chan_b_f2),
      .chan_b_f3         (fir_chan_b_f3),
      .chan_b_f4         (fir_chan_b_f4),
      .chan_b_f5         (fir_chan_b_f5),
      .chan_b_f6         (fir_chan_b_f6),
      .chan_b_f7         (fir_chan_b_f7),
      .chan_b_f8         (fir_chan_b_f8),
      .chan_b_f9         (fir_chan_b_f9),
      .chan_b_f10        (fir_chan_b_f10),
      .chan_b_f11        (fir_chan_b_f11),
      .chan_b_f12        (fir_chan_b_f12),
      .chan_b_f13        (fir_chan_b_f13),
      .chan_b_f14        (fir_chan_b_f14),
      .chan_b_f15        (fir_chan_b_f15),
      .chan_b_f16        (fir_chan_b_f16),
      .chan_b_f17        (fir_chan_b_f17),
      .chan_b_f18        (fir_chan_b_f18),
      .chan_b_f19        (fir_chan_b_f19),
      .tap_addr          (fir_tap_addr),
      .tap0              (fir_tap0),
      .tap1              (fir_tap1),
      .tap2              (fir_tap2),
      .tap3              (fir_tap3),
      .tap4              (fir_tap4),
      .tap5              (fir_tap5),
      .tap6              (fir_tap6),
      .tap7              (fir_tap7),
      .tap8              (fir_tap8),
      .tap9              (fir_tap9),
      .tap10             (fir_tap10),
      .tap11             (fir_tap11),
      .tap12             (fir_tap12),
      .tap13             (fir_tap13),
      .tap14             (fir_tap14),
      .tap15             (fir_tap15),
      .tap16             (fir_tap16),
      .tap17             (fir_tap17),
      .tap18             (fir_tap18),
      .tap19             (fir_tap19),
      .chan_a_d_2mhz_0   (fir_chan_a_d_2mhz_0),
      .chan_a_d_2mhz_1   (fir_chan_a_d_2mhz_1),
      .chan_a_d_2mhz_2   (fir_chan_a_d_2mhz_2),
      .chan_a_d_2mhz_3   (fir_chan_a_d_2mhz_3),
      .chan_a_d_2mhz_4   (fir_chan_a_d_2mhz_4),
      .chan_a_d_2mhz_5   (fir_chan_a_d_2mhz_5),
      .chan_a_d_2mhz_6   (fir_chan_a_d_2mhz_6),
      .chan_a_d_2mhz_7   (fir_chan_a_d_2mhz_7),
      .chan_a_d_2mhz_8   (fir_chan_a_d_2mhz_8),
      .chan_a_d_2mhz_9   (fir_chan_a_d_2mhz_9),
      .chan_a_d_2mhz_10  (fir_chan_a_d_2mhz_10),
      .chan_a_d_2mhz_11  (fir_chan_a_d_2mhz_11),
      .chan_a_d_2mhz_12  (fir_chan_a_d_2mhz_12),
      .chan_a_d_2mhz_13  (fir_chan_a_d_2mhz_13),
      .chan_a_d_2mhz_14  (fir_chan_a_d_2mhz_14),
      .chan_a_d_2mhz_15  (fir_chan_a_d_2mhz_15),
      .chan_a_d_2mhz_16  (fir_chan_a_d_2mhz_16),
      .chan_a_d_2mhz_17  (fir_chan_a_d_2mhz_17),
      .chan_a_d_2mhz_18  (fir_chan_a_d_2mhz_18),
      .chan_a_d_2mhz_19  (fir_chan_a_d_2mhz_19),
      .chan_b_d_2mhz_0   (fir_chan_b_d_2mhz_0),
      .chan_b_d_2mhz_1   (fir_chan_b_d_2mhz_1),
      .chan_b_d_2mhz_2   (fir_chan_b_d_2mhz_2),
      .chan_b_d_2mhz_3   (fir_chan_b_d_2mhz_3),
      .chan_b_d_2mhz_4   (fir_chan_b_d_2mhz_4),
      .chan_b_d_2mhz_5   (fir_chan_b_d_2mhz_5),
      .chan_b_d_2mhz_6   (fir_chan_b_d_2mhz_6),
      .chan_b_d_2mhz_7   (fir_chan_b_d_2mhz_7),
      .chan_b_d_2mhz_8   (fir_chan_b_d_2mhz_8),
      .chan_b_d_2mhz_9   (fir_chan_b_d_2mhz_9),
      .chan_b_d_2mhz_10  (fir_chan_b_d_2mhz_10),
      .chan_b_d_2mhz_11  (fir_chan_b_d_2mhz_11),
      .chan_b_d_2mhz_12  (fir_chan_b_d_2mhz_12),
      .chan_b_d_2mhz_13  (fir_chan_b_d_2mhz_13),
      .chan_b_d_2mhz_14  (fir_chan_b_d_2mhz_14),
      .chan_b_d_2mhz_15  (fir_chan_b_d_2mhz_15),
      .chan_b_d_2mhz_16  (fir_chan_b_d_2mhz_16),
      .chan_b_d_2mhz_17  (fir_chan_b_d_2mhz_17),
      .chan_b_d_2mhz_18  (fir_chan_b_d_2mhz_18),
      .chan_b_d_2mhz_19  (fir_chan_b_d_2mhz_19)
   );

   // directly instantiate DSPs. 7A15T has 45. in order to avoid
   // multiplexing clocks and creating clock skew, we do not share
   // DSPs between cores that use a different multiply clock
   // frequency. The FIR filter and distance FFT cores use a 120MHz
   // mutliply clock, while the angle FFT uses a 30MHz multiply
   // clock. DSPs 1-40 are reserved for the FIR and distance FFTs,
   // while 41-45 are reserved for the angle FFT.

   // TODO double the number of multiplies used for the angle FFT to
   // get better resolution before rounding.
   localparam DSP_A_DATA_WIDTH = 25;
   localparam DSP_B_DATA_WIDTH = 18;
   localparam DSP_P_DATA_WIDTH = 48;

   reg                                dsp_acc;
   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp1_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp1_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp1_p;

   always @(*) begin
      if (sample_enable) begin
         // TODO if the acc is too slow, compute the clock before and
         // register it.
         dsp_acc      = (fir_tap_addr != {FIR_POLY_BANK_LEN_LOG2{1'b0}});
         dsp1_a        = $signed(fir_tap0);
         dsp1_b        = $signed(fir_chan_a_d_2mhz_0);
         fir_chan_a_f0 = dsp1_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp1 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp1_a),
      .b     (dsp1_b),
      .p     (dsp1_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp2_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp2_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp2_p;

   always @(*) begin
      if (sample_enable) begin
         dsp2_a        = $signed(fir_tap1);
         dsp2_b        = $signed(fir_chan_a_d_2mhz_1);
         fir_chan_a_f1 = dsp2_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp2 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp2_a),
      .b     (dsp2_b),
      .p     (dsp2_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp3_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp3_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp3_p;

   always @(*) begin
      if (sample_enable) begin
         dsp3_a        = $signed(fir_tap2);
         dsp3_b        = $signed(fir_chan_a_d_2mhz_2);
         fir_chan_a_f2 = dsp3_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp3 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp3_a),
      .b     (dsp3_b),
      .p     (dsp3_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp4_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp4_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp4_p;

   always @(*) begin
      if (sample_enable) begin
         dsp4_a        = $signed(fir_tap3);
         dsp4_b        = $signed(fir_chan_a_d_2mhz_3);
         fir_chan_a_f3 = dsp4_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp4 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp4_a),
      .b     (dsp4_b),
      .p     (dsp4_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp5_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp5_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp5_p;

   always @(*) begin
      if (sample_enable) begin
         dsp5_a        = $signed(fir_tap4);
         dsp5_b        = $signed(fir_chan_a_d_2mhz_4);
         fir_chan_a_f4 = dsp5_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp5 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp5_a),
      .b     (dsp5_b),
      .p     (dsp5_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp6_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp6_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp6_p;

   always @(*) begin
      if (sample_enable) begin
         dsp6_a        = $signed(fir_tap5);
         dsp6_b        = $signed(fir_chan_a_d_2mhz_5);
         fir_chan_a_f5 = dsp6_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp6 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp6_a),
      .b     (dsp6_b),
      .p     (dsp6_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp7_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp7_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp7_p;

   always @(*) begin
      if (sample_enable) begin
         dsp7_a        = $signed(fir_tap6);
         dsp7_b        = $signed(fir_chan_a_d_2mhz_6);
         fir_chan_a_f6 = dsp7_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp7 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp7_a),
      .b     (dsp7_b),
      .p     (dsp7_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp8_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp8_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp8_p;

   always @(*) begin
      if (sample_enable) begin
         dsp8_a        = $signed(fir_tap7);
         dsp8_b        = $signed(fir_chan_a_d_2mhz_7);
         fir_chan_a_f7 = dsp8_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp8 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp8_a),
      .b     (dsp8_b),
      .p     (dsp8_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp9_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp9_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp9_p;

   always @(*) begin
      if (sample_enable) begin
         dsp9_a        = $signed(fir_tap8);
         dsp9_b        = $signed(fir_chan_a_d_2mhz_8);
         fir_chan_a_f8 = dsp9_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp9 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp9_a),
      .b     (dsp9_b),
      .p     (dsp9_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp10_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp10_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp10_p;

   always @(*) begin
      if (sample_enable) begin
         dsp10_a        = $signed(fir_tap9);
         dsp10_b        = $signed(fir_chan_a_d_2mhz_9);
         fir_chan_a_f9  = dsp10_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp10 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp10_a),
      .b     (dsp10_b),
      .p     (dsp10_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp11_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp11_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp11_p;

   always @(*) begin
      if (sample_enable) begin
         dsp11_a        = $signed(fir_tap10);
         dsp11_b        = $signed(fir_chan_a_d_2mhz_10);
         fir_chan_a_f10 = dsp11_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp11 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp11_a),
      .b     (dsp11_b),
      .p     (dsp11_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp12_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp12_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp12_p;

   always @(*) begin
      if (sample_enable) begin
         dsp12_a        = $signed(fir_tap11);
         dsp12_b        = $signed(fir_chan_a_d_2mhz_11);
         fir_chan_a_f11 = dsp12_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp12 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp12_a),
      .b     (dsp12_b),
      .p     (dsp12_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp13_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp13_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp13_p;

   always @(*) begin
      if (sample_enable) begin
         dsp13_a        = $signed(fir_tap12);
         dsp13_b        = $signed(fir_chan_a_d_2mhz_12);
         fir_chan_a_f12 = dsp13_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp13 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp13_a),
      .b     (dsp13_b),
      .p     (dsp13_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp14_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp14_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp14_p;

   always @(*) begin
      if (sample_enable) begin
         dsp14_a        = $signed(fir_tap13);
         dsp14_b        = $signed(fir_chan_a_d_2mhz_13);
         fir_chan_a_f13 = dsp14_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp14 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp14_a),
      .b     (dsp14_b),
      .p     (dsp14_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp15_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp15_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp15_p;

   always @(*) begin
      if (sample_enable) begin
         dsp15_a        = $signed(fir_tap14);
         dsp15_b        = $signed(fir_chan_a_d_2mhz_14);
         fir_chan_a_f14 = dsp15_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp15 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp15_a),
      .b     (dsp15_b),
      .p     (dsp15_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp16_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp16_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp16_p;

   always @(*) begin
      if (sample_enable) begin
         dsp16_a        = $signed(fir_tap15);
         dsp16_b        = $signed(fir_chan_a_d_2mhz_15);
         fir_chan_a_f15 = dsp16_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp16 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp16_a),
      .b     (dsp16_b),
      .p     (dsp16_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp17_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp17_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp17_p;

   always @(*) begin
      if (sample_enable) begin
         dsp17_a        = $signed(fir_tap16);
         dsp17_b        = $signed(fir_chan_a_d_2mhz_16);
         fir_chan_a_f16 = dsp17_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp17 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp17_a),
      .b     (dsp17_b),
      .p     (dsp17_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp18_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp18_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp18_p;

   always @(*) begin
      if (sample_enable) begin
         dsp18_a        = $signed(fir_tap17);
         dsp18_b        = $signed(fir_chan_a_d_2mhz_17);
         fir_chan_a_f17 = dsp18_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp18 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp18_a),
      .b     (dsp18_b),
      .p     (dsp18_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp19_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp19_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp19_p;

   always @(*) begin
      if (sample_enable) begin
         dsp19_a        = $signed(fir_tap18);
         dsp19_b        = $signed(fir_chan_a_d_2mhz_18);
         fir_chan_a_f18 = dsp19_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp19 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp19_a),
      .b     (dsp19_b),
      .p     (dsp19_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp20_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp20_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp20_p;

   always @(*) begin
      if (sample_enable) begin
         dsp20_a        = $signed(fir_tap19);
         dsp20_b        = $signed(fir_chan_a_d_2mhz_19);
         fir_chan_a_f19 = dsp20_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp20 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp20_a),
      .b     (dsp20_b),
      .p     (dsp20_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp21_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp21_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp21_p;

   always @(*) begin
      if (sample_enable) begin
         dsp21_a        = $signed(fir_tap0);
         dsp21_b        = $signed(fir_chan_b_d_2mhz_0);
         fir_chan_b_f0  = dsp21_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp21 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp21_a),
      .b     (dsp21_b),
      .p     (dsp21_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp22_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp22_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp22_p;

   always @(*) begin
      if (sample_enable) begin
         dsp22_a        = $signed(fir_tap1);
         dsp22_b        = $signed(fir_chan_b_d_2mhz_1);
         fir_chan_b_f1  = dsp22_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp22 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp22_a),
      .b     (dsp22_b),
      .p     (dsp22_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp23_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp23_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp23_p;

   always @(*) begin
      if (sample_enable) begin
         dsp23_a        = $signed(fir_tap2);
         dsp23_b        = $signed(fir_chan_b_d_2mhz_2);
         fir_chan_b_f2  = dsp23_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp23 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp23_a),
      .b     (dsp23_b),
      .p     (dsp23_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp24_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp24_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp24_p;

   always @(*) begin
      if (sample_enable) begin
         dsp24_a        = $signed(fir_tap3);
         dsp24_b        = $signed(fir_chan_b_d_2mhz_3);
         fir_chan_b_f3  = dsp24_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp24 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp24_a),
      .b     (dsp24_b),
      .p     (dsp24_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp25_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp25_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp25_p;

   always @(*) begin
      if (sample_enable) begin
         dsp25_a        = $signed(fir_tap4);
         dsp25_b        = $signed(fir_chan_b_d_2mhz_4);
         fir_chan_b_f4  = dsp25_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp25 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp25_a),
      .b     (dsp25_b),
      .p     (dsp25_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp26_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp26_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp26_p;

   always @(*) begin
      if (sample_enable) begin
         dsp26_a        = $signed(fir_tap5);
         dsp26_b        = $signed(fir_chan_b_d_2mhz_5);
         fir_chan_b_f5  = dsp26_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp26 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp26_a),
      .b     (dsp26_b),
      .p     (dsp26_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp27_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp27_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp27_p;

   always @(*) begin
      if (sample_enable) begin
         dsp27_a        = $signed(fir_tap6);
         dsp27_b        = $signed(fir_chan_b_d_2mhz_6);
         fir_chan_b_f6  = dsp27_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp27 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp27_a),
      .b     (dsp27_b),
      .p     (dsp27_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp28_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp28_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp28_p;

   always @(*) begin
      if (sample_enable) begin
         dsp28_a        = $signed(fir_tap7);
         dsp28_b        = $signed(fir_chan_b_d_2mhz_7);
         fir_chan_b_f7  = dsp28_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp28 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp28_a),
      .b     (dsp28_b),
      .p     (dsp28_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp29_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp29_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp29_p;

   always @(*) begin
      if (sample_enable) begin
         dsp29_a        = $signed(fir_tap8);
         dsp29_b        = $signed(fir_chan_b_d_2mhz_8);
         fir_chan_b_f8  = dsp29_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp29 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp29_a),
      .b     (dsp29_b),
      .p     (dsp29_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp30_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp30_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp30_p;

   always @(*) begin
      if (sample_enable) begin
         dsp30_a        = $signed(fir_tap9);
         dsp30_b        = $signed(fir_chan_b_d_2mhz_9);
         fir_chan_b_f9  = dsp30_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp30 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp30_a),
      .b     (dsp30_b),
      .p     (dsp30_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp31_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp31_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp31_p;

   always @(*) begin
      if (sample_enable) begin
         dsp31_a        = $signed(fir_tap10);
         dsp31_b        = $signed(fir_chan_b_d_2mhz_10);
         fir_chan_b_f10 = dsp31_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp31 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp31_a),
      .b     (dsp31_b),
      .p     (dsp31_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp32_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp32_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp32_p;

   always @(*) begin
      if (sample_enable) begin
         dsp32_a        = $signed(fir_tap11);
         dsp32_b        = $signed(fir_chan_b_d_2mhz_11);
         fir_chan_b_f11 = dsp32_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp32 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp32_a),
      .b     (dsp32_b),
      .p     (dsp32_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp33_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp33_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp33_p;

   always @(*) begin
      if (sample_enable) begin
         dsp33_a        = $signed(fir_tap12);
         dsp33_b        = $signed(fir_chan_b_d_2mhz_12);
         fir_chan_b_f12 = dsp33_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp33 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp33_a),
      .b     (dsp33_b),
      .p     (dsp33_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp34_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp34_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp34_p;

   always @(*) begin
      if (sample_enable) begin
         dsp34_a        = $signed(fir_tap13);
         dsp34_b        = $signed(fir_chan_b_d_2mhz_13);
         fir_chan_b_f13 = dsp34_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp34 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp34_a),
      .b     (dsp34_b),
      .p     (dsp34_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp35_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp35_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp35_p;

   always @(*) begin
      if (sample_enable) begin
         dsp35_a        = $signed(fir_tap14);
         dsp35_b        = $signed(fir_chan_b_d_2mhz_14);
         fir_chan_b_f14 = dsp35_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp35 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp35_a),
      .b     (dsp35_b),
      .p     (dsp35_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp36_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp36_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp36_p;

   always @(*) begin
      if (sample_enable) begin
         dsp36_a        = $signed(fir_tap15);
         dsp36_b        = $signed(fir_chan_b_d_2mhz_15);
         fir_chan_b_f15 = dsp36_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp36 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp36_a),
      .b     (dsp36_b),
      .p     (dsp36_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp37_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp37_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp37_p;

   always @(*) begin
      if (sample_enable) begin
         dsp37_a        = $signed(fir_tap16);
         dsp37_b        = $signed(fir_chan_b_d_2mhz_16);
         fir_chan_b_f16 = dsp37_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp37 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp37_a),
      .b     (dsp37_b),
      .p     (dsp37_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp38_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp38_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp38_p;

   always @(*) begin
      if (sample_enable) begin
         dsp38_a        = $signed(fir_tap17);
         dsp38_b        = $signed(fir_chan_b_d_2mhz_17);
         fir_chan_b_f17 = dsp38_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp38 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp38_a),
      .b     (dsp38_b),
      .p     (dsp38_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp39_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp39_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp39_p;

   always @(*) begin
      if (sample_enable) begin
         dsp39_a        = $signed(fir_tap18);
         dsp39_b        = $signed(fir_chan_b_d_2mhz_18);
         fir_chan_b_f18 = dsp39_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp39 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp39_a),
      .b     (dsp39_b),
      .p     (dsp39_p)
   );

   reg signed [DSP_A_DATA_WIDTH-1:0]  dsp40_a;
   reg signed [DSP_B_DATA_WIDTH-1:0]  dsp40_b;
   wire signed [DSP_P_DATA_WIDTH-1:0] dsp40_p;

   always @(*) begin
      if (sample_enable) begin
         dsp40_a        = $signed(fir_tap19);
         dsp40_b        = $signed(fir_chan_b_d_2mhz_19);
         fir_chan_b_f19 = dsp40_p[FIR_INTERNAL_WIDTH-1:0];
      end
   end

   dsp dsp40 (
      .clk_i (clk_120mhz),
      .acc   (dsp_acc),
      .a     (dsp40_a),
      .b     (dsp40_b),
      .p     (dsp40_p)
   );



   reg [FFT_DIST_N_LOG2-1:0]     slow_sample_ctr = {FFT_DIST_N_LOG2{1'b0}};

   always @(posedge clk_i) begin
      if (clk_2mhz_pos_en) begin
         if (sample_enable) begin
            if (slow_sample_ctr == FFT_DIST_N-1) begin
               slow_sample_ctr <= 0;
            end else begin
               slow_sample_ctr <= slow_sample_ctr + 1'b1;
            end
         end else begin
            slow_sample_ctr <= 0;
         end
      end else begin
         slow_sample_ctr <= slow_sample_ctr;
      end
   end

   reg signed [ADC_DATA_WIDTH-1:0] chan_a_mem [0:FFT_DIST_N-1];
   reg signed [ADC_DATA_WIDTH-1:0] chan_b_mem [0:FFT_DIST_N-1];
   reg signed [ADC_DATA_WIDTH-1:0] chan_c_mem [0:FFT_DIST_N-1];
   reg signed [ADC_DATA_WIDTH-1:0] chan_d_mem [0:FFT_DIST_N-1];
   reg signed [ADC_DATA_WIDTH-1:0] chan_e_mem [0:FFT_DIST_N-1];
   reg signed [ADC_DATA_WIDTH-1:0] chan_f_mem [0:FFT_DIST_N-1];
   reg signed [ADC_DATA_WIDTH-1:0] chan_g_mem [0:FFT_DIST_N-1];
   reg signed [ADC_DATA_WIDTH-1:0] chan_h_mem [0:FFT_DIST_N-1];

   integer                 i;
   initial begin
      for (i=0; i<FFT_DIST_N; i=i+1) begin
         chan_a_mem[i] <= {ADC_DATA_WIDTH{1'b0}};
         chan_b_mem[i] <= {ADC_DATA_WIDTH{1'b0}};
         chan_c_mem[i] <= {ADC_DATA_WIDTH{1'b0}};
         chan_d_mem[i] <= {ADC_DATA_WIDTH{1'b0}};
         chan_e_mem[i] <= {ADC_DATA_WIDTH{1'b0}};
         chan_f_mem[i] <= {ADC_DATA_WIDTH{1'b0}};
         chan_g_mem[i] <= {ADC_DATA_WIDTH{1'b0}};
         chan_h_mem[i] <= {ADC_DATA_WIDTH{1'b0}};
      end
   end

   reg chan_mem_we_toggle                     = 1'b0;
   wire chan_mem_we                           = sample_enable && chan_mem_we_toggle;
   wire [FFT_DIST_N_LOG2-1:0] chan_mem_wr_adr = slow_sample_ctr;
   wire [FFT_DIST_N_LOG2-1:0] chan_mem_rd_adr = fft_dist_in_ctr;

   wire signed [ADC_DATA_WIDTH:0]  chan_a_mem_int = chan_a_mem_wr_do + chan_a_filtered >>> 1;
   wire signed [ADC_DATA_WIDTH:0]  chan_b_mem_int = chan_b_mem_wr_do + chan_b_filtered >>> 1;
   wire signed [ADC_DATA_WIDTH:0]  chan_c_mem_int = chan_c_mem_wr_do + chan_a_filtered >>> 1;
   wire signed [ADC_DATA_WIDTH:0]  chan_d_mem_int = chan_d_mem_wr_do + chan_b_filtered >>> 1;
   wire signed [ADC_DATA_WIDTH:0]  chan_e_mem_int = chan_e_mem_wr_do + chan_a_filtered >>> 1;
   wire signed [ADC_DATA_WIDTH:0]  chan_f_mem_int = chan_f_mem_wr_do + chan_b_filtered >>> 1;
   wire signed [ADC_DATA_WIDTH:0]  chan_g_mem_int = chan_g_mem_wr_do + chan_a_filtered >>> 1;
   wire signed [ADC_DATA_WIDTH:0]  chan_h_mem_int = chan_h_mem_wr_do + chan_b_filtered >>> 1;

   wire signed [ADC_DATA_WIDTH-1:0] chan_a_mem_di = sweep_ctr > 3'd3 ? chan_a_mem_int : chan_a_filtered;
   wire signed [ADC_DATA_WIDTH-1:0] chan_b_mem_di = sweep_ctr > 3'd3 ? chan_b_mem_int : chan_b_filtered;
   wire signed [ADC_DATA_WIDTH-1:0] chan_c_mem_di = sweep_ctr > 3'd3 ? chan_c_mem_int : chan_a_filtered;
   wire signed [ADC_DATA_WIDTH-1:0] chan_d_mem_di = sweep_ctr > 3'd3 ? chan_d_mem_int : chan_b_filtered;
   wire signed [ADC_DATA_WIDTH-1:0] chan_e_mem_di = sweep_ctr > 3'd3 ? chan_e_mem_int : chan_a_filtered;
   wire signed [ADC_DATA_WIDTH-1:0] chan_f_mem_di = sweep_ctr > 3'd3 ? chan_f_mem_int : chan_b_filtered;
   wire signed [ADC_DATA_WIDTH-1:0] chan_g_mem_di = sweep_ctr > 3'd3 ? chan_g_mem_int : chan_a_filtered;
   wire signed [ADC_DATA_WIDTH-1:0] chan_h_mem_di = sweep_ctr > 3'd3 ? chan_h_mem_int : chan_b_filtered;

   reg signed [ADC_DATA_WIDTH-1:0]  chan_a_mem_wr_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_b_mem_wr_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_c_mem_wr_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_d_mem_wr_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_e_mem_wr_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_f_mem_wr_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_g_mem_wr_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_h_mem_wr_do = {ADC_DATA_WIDTH{1'b0}};

   always @(posedge clk_i) begin
      if (ce) begin
         if (clk_4mhz_pos_en) begin
            if (chan_mem_we_toggle) begin
               chan_mem_we_toggle <= 1'b0;
            end else begin
               chan_mem_we_toggle <= 1'b1;
            end
         end else begin
            chan_mem_we_toggle <= 1'b0;
         end
      end else begin // if (ce)
         chan_mem_we_toggle <= 1'b0;
      end // else: !if(ce)
   end

   always @(posedge clk_i) begin
      if (clk_4mhz_pos_en) begin
         if (chan_mem_we) begin
            chan_a_mem[chan_mem_wr_adr] <= chan_a_mem_di;
            chan_b_mem[chan_mem_wr_adr] <= chan_b_mem_di;
            chan_c_mem[chan_mem_wr_adr] <= chan_c_mem_di;
            chan_d_mem[chan_mem_wr_adr] <= chan_d_mem_di;
            chan_e_mem[chan_mem_wr_adr] <= chan_e_mem_di;
            chan_f_mem[chan_mem_wr_adr] <= chan_f_mem_di;
            chan_g_mem[chan_mem_wr_adr] <= chan_g_mem_di;
            chan_h_mem[chan_mem_wr_adr] <= chan_h_mem_di;
         end else begin
            chan_a_mem_wr_do <= chan_a_mem[chan_mem_wr_adr];
            chan_b_mem_wr_do <= chan_b_mem[chan_mem_wr_adr];
            chan_c_mem_wr_do <= chan_c_mem[chan_mem_wr_adr];
            chan_d_mem_wr_do <= chan_d_mem[chan_mem_wr_adr];
            chan_e_mem_wr_do <= chan_e_mem[chan_mem_wr_adr];
            chan_f_mem_wr_do <= chan_f_mem[chan_mem_wr_adr];
            chan_g_mem_wr_do <= chan_g_mem[chan_mem_wr_adr];
            chan_h_mem_wr_do <= chan_h_mem[chan_mem_wr_adr];
         end // else: !if(chan_mem_we)
      end // if (clk_4mhz_pos_en)
   end

   // Infers dual-port ram, which enables using the 40MHz clock for
   // reading and the 2MHz clock for writing. Use this in 'no change'
   // mode.
   reg signed [ADC_DATA_WIDTH-1:0]  chan_a_mem_rd_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_b_mem_rd_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_c_mem_rd_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_d_mem_rd_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_e_mem_rd_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_f_mem_rd_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_g_mem_rd_do = {ADC_DATA_WIDTH{1'b0}};
   reg signed [ADC_DATA_WIDTH-1:0]  chan_h_mem_rd_do = {ADC_DATA_WIDTH{1'b0}};

   always @(posedge clk_i) begin
      chan_a_mem_rd_do <= chan_a_mem[chan_mem_rd_adr];
      chan_b_mem_rd_do <= chan_b_mem[chan_mem_rd_adr];
      chan_c_mem_rd_do <= chan_c_mem[chan_mem_rd_adr];
      chan_d_mem_rd_do <= chan_d_mem[chan_mem_rd_adr];
      chan_e_mem_rd_do <= chan_e_mem[chan_mem_rd_adr];
      chan_f_mem_rd_do <= chan_f_mem[chan_mem_rd_adr];
      chan_g_mem_rd_do <= chan_g_mem[chan_mem_rd_adr];
      chan_h_mem_rd_do <= chan_h_mem[chan_mem_rd_adr];
   end


   // FFT distance calculation
   reg [FFT_DIST_N_LOG2-1:0]  fft_dist_in_ctr = {FFT_DIST_N_LOG2{1'b0}};
   wire [FFT_DIST_N_LOG2-1:0] fft_dist_out_ctr;
   wire                       fft_dist_sync;

   // count input to distance FFT
   always @(posedge clk_i) begin
      if (fft_dist_enable) begin
         fft_dist_in_ctr <= fft_dist_in_ctr + 1'b1;
      end else begin
         fft_dist_in_ctr <= {FFT_DIST_N_LOG2{1'b0}};
      end
   end // always @ (posedge clk_i)


   // Signal when last output of distance-computing FFT has been
   // processed.
   always @(posedge clk_i) begin
      if (fft_dist_out_ctr == FFT_DIST_N-1) begin
         fft_dist_done <= 1'b1;
      end else begin
         fft_dist_done <= 1'b0;
      end
   end

   // channel A
   wire chan_a_fft_sync;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_a_fft_dout_re;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_a_fft_dout_im;

   fft_r22sdf #(
      .N              (FFT_DIST_N),
      .N_LOG2         (FFT_DIST_N_LOG2),
      .N_STAGES       (FFT_DIST_N_STAGES),
      .INPUT_WIDTH    (FFT_DIST_INPUT_WIDTH),
      .TWIDDLE_WIDTH  (FFT_TWIDDLE_WIDTH),
      .INTERNAL_WIDTH (FFT_DIST_INTERNAL_WIDTH),
      .OUTPUT_WIDTH   (FFT_DIST_OUTPUT_WIDTH)
   ) fft_chan_a (
      .clk_i      (clk_i),
      .clk_3x_i   (clk_120mhz),
      .ce_i       (fft_dist_enable),
      .sync_o     (fft_dist_sync),
      .data_ctr_o (fft_dist_out_ctr),
      .data_re_i  (chan_a_mem_rd_do),
      .data_im_i  ({FFT_DIST_OUTPUT_WIDTH{1'b0}}),
      .data_re_o  (chan_a_fft_dout_re),
      .data_im_o  (chan_a_fft_dout_im)
   );

   // channel B distance
   wire chan_b_fft_sync;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_b_fft_dout_re;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_b_fft_dout_im;

   fft_r22sdf #(
      .N              (FFT_DIST_N),
      .N_LOG2         (FFT_DIST_N_LOG2),
      .N_STAGES       (FFT_DIST_N_STAGES),
      .INPUT_WIDTH    (FFT_DIST_INPUT_WIDTH),
      .TWIDDLE_WIDTH  (FFT_TWIDDLE_WIDTH),
      .INTERNAL_WIDTH (FFT_DIST_INTERNAL_WIDTH),
      .OUTPUT_WIDTH   (FFT_DIST_OUTPUT_WIDTH)
   ) fft_chan_b (
      .clk_i     (clk_i),
      .clk_3x_i  (clk_120mhz),
      .ce_i      (fft_dist_enable),
      .data_re_i (chan_b_mem_rd_do),
      .data_im_i ({FFT_DIST_OUTPUT_WIDTH{1'b0}}),
      .data_re_o (chan_b_fft_dout_re),
      .data_im_o (chan_b_fft_dout_im)
   );

   // channel C distance
   wire chan_c_fft_sync;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_c_fft_dout_re;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_c_fft_dout_im;

   fft_r22sdf #(
      .N              (FFT_DIST_N),
      .N_LOG2         (FFT_DIST_N_LOG2),
      .N_STAGES       (FFT_DIST_N_STAGES),
      .INPUT_WIDTH    (FFT_DIST_INPUT_WIDTH),
      .TWIDDLE_WIDTH  (FFT_TWIDDLE_WIDTH),
      .INTERNAL_WIDTH (FFT_DIST_INTERNAL_WIDTH),
      .OUTPUT_WIDTH   (FFT_DIST_OUTPUT_WIDTH)
   ) fft_chan_c (
      .clk_i     (clk_i),
      .clk_3x_i  (clk_120mhz),
      .ce_i      (fft_dist_enable),
      .data_re_i (chan_c_mem_rd_do),
      .data_im_i ({FFT_DIST_OUTPUT_WIDTH{1'b0}}),
      .data_re_o (chan_c_fft_dout_re),
      .data_im_o (chan_c_fft_dout_im)
   );

   // channel D distance
   wire chan_d_fft_sync;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_d_fft_dout_re;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_d_fft_dout_im;

   fft_r22sdf #(
      .N              (FFT_DIST_N),
      .N_LOG2         (FFT_DIST_N_LOG2),
      .N_STAGES       (FFT_DIST_N_STAGES),
      .INPUT_WIDTH    (FFT_DIST_INPUT_WIDTH),
      .TWIDDLE_WIDTH  (FFT_TWIDDLE_WIDTH),
      .INTERNAL_WIDTH (FFT_DIST_INTERNAL_WIDTH),
      .OUTPUT_WIDTH   (FFT_DIST_OUTPUT_WIDTH)
   ) fft_chan_d (
      .clk_i     (clk_i),
      .clk_3x_i  (clk_120mhz),
      .ce_i      (fft_dist_enable),
      .data_re_i (chan_d_mem_rd_do),
      .data_im_i ({FFT_DIST_OUTPUT_WIDTH{1'b0}}),
      .data_re_o (chan_d_fft_dout_re),
      .data_im_o (chan_d_fft_dout_im)
   );

   // channel E distance
   wire chan_e_fft_sync;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_e_fft_dout_re;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_e_fft_dout_im;

   fft_r22sdf #(
      .N              (FFT_DIST_N),
      .N_LOG2         (FFT_DIST_N_LOG2),
      .N_STAGES       (FFT_DIST_N_STAGES),
      .INPUT_WIDTH    (FFT_DIST_INPUT_WIDTH),
      .TWIDDLE_WIDTH  (FFT_TWIDDLE_WIDTH),
      .INTERNAL_WIDTH (FFT_DIST_INTERNAL_WIDTH),
      .OUTPUT_WIDTH   (FFT_DIST_OUTPUT_WIDTH)
   ) fft_chan_e (
      .clk_i     (clk_i),
      .clk_3x_i  (clk_120mhz),
      .ce_i      (fft_dist_enable),
      .data_re_i (chan_e_mem_rd_do),
      .data_im_i ({FFT_DIST_OUTPUT_WIDTH{1'b0}}),
      .data_re_o (chan_e_fft_dout_re),
      .data_im_o (chan_e_fft_dout_im)
   );

   // channel F distance
   wire chan_f_fft_sync;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_f_fft_dout_re;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_f_fft_dout_im;

   fft_r22sdf #(
      .N              (FFT_DIST_N),
      .N_LOG2         (FFT_DIST_N_LOG2),
      .N_STAGES       (FFT_DIST_N_STAGES),
      .INPUT_WIDTH    (FFT_DIST_INPUT_WIDTH),
      .TWIDDLE_WIDTH  (FFT_TWIDDLE_WIDTH),
      .INTERNAL_WIDTH (FFT_DIST_INTERNAL_WIDTH),
      .OUTPUT_WIDTH   (FFT_DIST_OUTPUT_WIDTH)
   ) fft_chan_f (
      .clk_i     (clk_i),
      .clk_3x_i  (clk_120mhz),
      .ce_i      (fft_dist_enable),
      .data_re_i (chan_f_mem_rd_do),
      .data_im_i ({FFT_DIST_OUTPUT_WIDTH{1'b0}}),
      .data_re_o (chan_f_fft_dout_re),
      .data_im_o (chan_f_fft_dout_im)
   );

   // channel G distance
   wire chan_g_fft_sync;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_g_fft_dout_re;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_g_fft_dout_im;

   fft_r22sdf #(
      .N              (FFT_DIST_N),
      .N_LOG2         (FFT_DIST_N_LOG2),
      .N_STAGES       (FFT_DIST_N_STAGES),
      .INPUT_WIDTH    (FFT_DIST_INPUT_WIDTH),
      .TWIDDLE_WIDTH  (FFT_TWIDDLE_WIDTH),
      .INTERNAL_WIDTH (FFT_DIST_INTERNAL_WIDTH),
      .OUTPUT_WIDTH   (FFT_DIST_OUTPUT_WIDTH)
   ) fft_chan_g (
      .clk_i     (clk_i),
      .clk_3x_i  (clk_120mhz),
      .ce_i      (fft_dist_enable),
      .data_re_i (chan_g_mem_rd_do),
      .data_im_i ({FFT_DIST_OUTPUT_WIDTH{1'b0}}),
      .data_re_o (chan_g_fft_dout_re),
      .data_im_o (chan_g_fft_dout_im)
   );

   // channel H distance
   wire chan_h_fft_sync;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_h_fft_dout_re;
   wire signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_h_fft_dout_im;

   fft_r22sdf #(
      .N              (FFT_DIST_N),
      .N_LOG2         (FFT_DIST_N_LOG2),
      .N_STAGES       (FFT_DIST_N_STAGES),
      .INPUT_WIDTH    (FFT_DIST_INPUT_WIDTH),
      .TWIDDLE_WIDTH  (FFT_TWIDDLE_WIDTH),
      .INTERNAL_WIDTH (FFT_DIST_INTERNAL_WIDTH),
      .OUTPUT_WIDTH   (FFT_DIST_OUTPUT_WIDTH)
   ) fft_chan_h (
      .clk_i     (clk_i),
      .clk_3x_i  (clk_120mhz),
      .ce_i      (fft_dist_enable),
      .data_re_i (chan_h_mem_rd_do),
      .data_im_i ({FFT_DIST_OUTPUT_WIDTH{1'b0}}),
      .data_re_o (chan_h_fft_dout_re),
      .data_im_o (chan_h_fft_dout_im)
   );

   // store distance data
   wire                                    chan_dist_mem_we   = fft_dist_enable;
   reg [FFT_DIST_N_LOG2-1:0]               fft_angle_mem_addr = {FFT_DIST_N_LOG2{1'b0}};

   // FFT distance result RAM
   // TODO need to shift fft dist outputs to be the same as fft inputs
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_a_dist_re_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_a_dist_im_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_b_dist_re_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_b_dist_im_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_c_dist_re_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_c_dist_im_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_d_dist_re_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_d_dist_im_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_e_dist_re_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_e_dist_im_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_f_dist_re_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_f_dist_im_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_g_dist_re_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_g_dist_im_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_h_dist_re_mem [0:FFT_DIST_N-1];
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0]  chan_h_dist_im_mem [0:FFT_DIST_N-1];

   initial begin
      for (i=0; i<FFT_DIST_N; i=i+1) begin
         chan_a_dist_re_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_a_dist_im_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_b_dist_re_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_b_dist_im_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_c_dist_re_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_c_dist_im_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_d_dist_re_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_d_dist_im_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_e_dist_re_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_e_dist_im_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_f_dist_re_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_f_dist_im_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_g_dist_re_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_g_dist_im_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_h_dist_re_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
         chan_h_dist_im_mem[i] <= {FFT_DIST_OUTPUT_WIDTH{1'b0}};
      end
   end

   wire [FFT_DIST_N_LOG2-1:0] chan_dist_mem_wr_adr = fft_dist_out_ctr;

   // 'no change' RAM. This is faster than read first. We use
   // dual-port RAM for this, which permits writing and reading at
   // different rates.
   always @(posedge clk_i) begin
      if (chan_dist_mem_we) begin
         chan_a_dist_re_mem[chan_dist_mem_wr_adr] <= chan_a_fft_dout_re;
         chan_a_dist_im_mem[chan_dist_mem_wr_adr] <= chan_a_fft_dout_im;
         chan_b_dist_re_mem[chan_dist_mem_wr_adr] <= chan_b_fft_dout_re;
         chan_b_dist_im_mem[chan_dist_mem_wr_adr] <= chan_b_fft_dout_im;
         chan_c_dist_re_mem[chan_dist_mem_wr_adr] <= chan_c_fft_dout_re;
         chan_c_dist_im_mem[chan_dist_mem_wr_adr] <= chan_c_fft_dout_im;
         chan_d_dist_re_mem[chan_dist_mem_wr_adr] <= chan_d_fft_dout_re;
         chan_d_dist_im_mem[chan_dist_mem_wr_adr] <= chan_d_fft_dout_im;
         chan_e_dist_re_mem[chan_dist_mem_wr_adr] <= chan_e_fft_dout_re;
         chan_e_dist_im_mem[chan_dist_mem_wr_adr] <= chan_e_fft_dout_im;
         chan_f_dist_re_mem[chan_dist_mem_wr_adr] <= chan_f_fft_dout_re;
         chan_f_dist_im_mem[chan_dist_mem_wr_adr] <= chan_f_fft_dout_im;
         chan_g_dist_re_mem[chan_dist_mem_wr_adr] <= chan_g_fft_dout_re;
         chan_g_dist_im_mem[chan_dist_mem_wr_adr] <= chan_g_fft_dout_im;
         chan_h_dist_re_mem[chan_dist_mem_wr_adr] <= chan_h_fft_dout_re;
         chan_h_dist_im_mem[chan_dist_mem_wr_adr] <= chan_h_fft_dout_im;
      end
   end

   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_a_dist_re_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_a_dist_im_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_b_dist_re_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_b_dist_im_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_c_dist_re_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_c_dist_im_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_d_dist_re_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_d_dist_im_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_e_dist_re_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_e_dist_im_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_f_dist_re_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_f_dist_im_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_g_dist_re_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_g_dist_im_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_h_dist_re_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_h_dist_im_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};

   wire [FFT_DIST_N_LOG2-1:0] chan_dist_mem_rd_adr = fft_angle_dist_ctr;

   // 2nd port of FFT distance dual RAM.
   always @(posedge clk_10mhz) begin
      chan_a_dist_re_mem_rd_do <= chan_a_dist_re_mem[chan_dist_mem_rd_adr];
      chan_a_dist_im_mem_rd_do <= chan_a_dist_im_mem[chan_dist_mem_rd_adr];
      chan_b_dist_re_mem_rd_do <= chan_b_dist_re_mem[chan_dist_mem_rd_adr];
      chan_b_dist_im_mem_rd_do <= chan_b_dist_im_mem[chan_dist_mem_rd_adr];
      chan_c_dist_re_mem_rd_do <= chan_c_dist_re_mem[chan_dist_mem_rd_adr];
      chan_c_dist_im_mem_rd_do <= chan_c_dist_im_mem[chan_dist_mem_rd_adr];
      chan_d_dist_re_mem_rd_do <= chan_d_dist_re_mem[chan_dist_mem_rd_adr];
      chan_d_dist_im_mem_rd_do <= chan_d_dist_im_mem[chan_dist_mem_rd_adr];
      chan_e_dist_re_mem_rd_do <= chan_e_dist_re_mem[chan_dist_mem_rd_adr];
      chan_e_dist_im_mem_rd_do <= chan_e_dist_im_mem[chan_dist_mem_rd_adr];
      chan_f_dist_re_mem_rd_do <= chan_f_dist_re_mem[chan_dist_mem_rd_adr];
      chan_f_dist_im_mem_rd_do <= chan_f_dist_im_mem[chan_dist_mem_rd_adr];
      chan_g_dist_re_mem_rd_do <= chan_g_dist_re_mem[chan_dist_mem_rd_adr];
      chan_g_dist_im_mem_rd_do <= chan_g_dist_im_mem[chan_dist_mem_rd_adr];
      chan_h_dist_re_mem_rd_do <= chan_h_dist_re_mem[chan_dist_mem_rd_adr];
      chan_h_dist_im_mem_rd_do <= chan_h_dist_im_mem[chan_dist_mem_rd_adr];
   end

   // TODO this multiplexor maybe inefficient if it actually uses 8
   // bits for selection. If so reimplement it with RAM or a pipeline
   // register.
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_dist_re_mem_rd_do;
   reg signed [FFT_DIST_OUTPUT_WIDTH-1:0] chan_dist_im_mem_rd_do;
   always @(*) begin
      case (fft_angle_angle_ctr)
      8'd0:
        begin
           chan_dist_re_mem_rd_do = chan_a_dist_re_mem_rd_do;
           chan_dist_im_mem_rd_do = chan_a_dist_im_mem_rd_do;
        end
      8'd1:
        begin
           chan_dist_re_mem_rd_do = chan_b_dist_re_mem_rd_do;
           chan_dist_im_mem_rd_do = chan_b_dist_im_mem_rd_do;
        end
      8'd2:
        begin
           chan_dist_re_mem_rd_do = chan_c_dist_re_mem_rd_do;
           chan_dist_im_mem_rd_do = chan_c_dist_im_mem_rd_do;
        end
      8'd3:
        begin
           chan_dist_re_mem_rd_do = chan_d_dist_re_mem_rd_do;
           chan_dist_im_mem_rd_do = chan_d_dist_im_mem_rd_do;
        end
      8'd4:
        begin
           chan_dist_re_mem_rd_do = chan_e_dist_re_mem_rd_do;
           chan_dist_im_mem_rd_do = chan_e_dist_im_mem_rd_do;
        end
      8'd5:
        begin
           chan_dist_re_mem_rd_do = chan_f_dist_re_mem_rd_do;
           chan_dist_im_mem_rd_do = chan_f_dist_im_mem_rd_do;
        end
      8'd6:
        begin
           chan_dist_re_mem_rd_do = chan_g_dist_re_mem_rd_do;
           chan_dist_im_mem_rd_do = chan_g_dist_im_mem_rd_do;
        end
      8'd7:
        begin
           chan_dist_re_mem_rd_do = chan_h_dist_re_mem_rd_do;
           chan_dist_im_mem_rd_do = chan_h_dist_im_mem_rd_do;
        end
      default:
        begin
           chan_dist_re_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
           chan_dist_im_mem_rd_do = {FFT_DIST_OUTPUT_WIDTH{1'b0}};
        end
      endcase // case (fft_angle_angle_ctr)
   end // always @ (*)

   reg [FFT_DIST_N-1:0] fft_angle_dist_ctr  = {FFT_DIST_N{1'b0}};
   reg [7:0]            fft_angle_angle_ctr = {8'b0};
   reg                  fft_angle_done      = 1'b0;

   always @(posedge clk_10mhz) begin
      if (fft_angle_enable) begin
         fft_angle_angle_ctr     <= fft_angle_angle_ctr + 1'b1;
         if (fft_angle_angle_ctr == 8'd255) begin
            if (fft_angle_dist_ctr == FFT_DIST_N-1) begin
               fft_angle_done <= 1'b1;
            end else begin
               fft_angle_done <= 1'b0;
            end
            fft_angle_dist_ctr  <= fft_angle_dist_ctr + 1'b1;
         end else begin
            fft_angle_dist_ctr <= fft_angle_dist_ctr;
         end
      end else begin
         fft_angle_angle_ctr    <= 8'd0;
         fft_angle_dist_ctr     <= {FFT_DIST_N{1'b0}};
      end
   end

   wire fft_angle_sync;
   wire [7:0] fft_angle_data_ctr;
   wire [FFT_ANGLE_OUTPUT_WIDTH-1:0] fft_angle_data_re_o;
   wire [FFT_ANGLE_OUTPUT_WIDTH-1:0] fft_angle_data_im_o;
   fft_r22sdf #(
      .N              (FFT_ANGLE_N),
      .N_LOG2         (FFT_ANGLE_N_LOG2),
      .N_STAGES       (FFT_ANGLE_N_STAGES),
      .INPUT_WIDTH    (FFT_ANGLE_INPUT_WIDTH),
      .TWIDDLE_WIDTH  (FFT_TWIDDLE_WIDTH),
      .INTERNAL_WIDTH (FFT_ANGLE_INTERNAL_WIDTH),
      .OUTPUT_WIDTH   (FFT_ANGLE_OUTPUT_WIDTH)
   ) fft_angle (
      .clk_i        (clk_10mhz),
      .clk_3x_i     (clk_30mhz), // TODO rename this...
      .ce_i         (fft_angle_enable),
      .sync_o       (fft_angle_sync),
      .data_ctr_o   (fft_angle_data_ctr),
      .data_re_i    (chan_dist_re_mem_rd_do),
      .data_im_i    (chan_dist_im_mem_rd_do),
      .data_re_o    (fft_angle_data_re_o),
      .data_im_o    (fft_angle_data_im_o)
   );

   wire [2*FFT_ANGLE_OUTPUT_WIDTH-1:0] fft_angle_data = {fft_angle_data_re_o, fft_angle_data_im_o};

   reg [2:0]     usb_byte_ctr = 3'd0;
   always @(negedge ft_clkout_i) begin
      if (fft_angle_sync) begin
         if (usb_byte_ctr == 3'd5) begin
            usb_byte_ctr <= 3'd0;
         end else begin
            usb_byte_ctr <= usb_byte_ctr + 1'b1;
         end
      end else begin
         usb_byte_ctr <= 3'd0;
      end
   end

   reg [USB_DATA_WIDTH-1:0]        usb_rdata;
   reg [USB_DATA_WIDTH-1:0]        usb_wdata;
   always @(*) begin
      case (usb_byte_ctr)
      3'd0:
        begin
           usb_wdata = fft_angle_data_re_o[7:0];
        end
      3'd1:
        begin
           usb_wdata = fft_angle_data_re_o[15:8];
        end
      3'd2:
        begin
           usb_wdata = fft_angle_data_re_o[23:16];
        end
      3'd3:
        begin
           usb_wdata = fft_angle_data_im_o[7:0];
        end
      3'd4:
        begin
           usb_wdata = fft_angle_data_im_o[15:8];
        end
      3'd5:
        begin
           usb_wdata = fft_angle_data_im_o[23:16];
        end
      default:
        begin
           usb_wdata = 8'd0;
        end
      endcase // case (usb_byte_ctr)
   end // always @ (*)

   usb #(
      .DATA_WIDTH (USB_DATA_WIDTH)
   ) usb (
      .data_io     (ft_data_io),
      .wdata_i     (usb_wdata),
      .send_data_i (fft_angle_sync),
      .txe_n_i     (ft_txe_n_i),
      .wr_n_o      (ft_wr_n_o),
      .clk_60mhz_i (ft_clkout_i)
   );

endmodule // top
