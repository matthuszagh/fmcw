`default_nettype none

`include "fmcw_defines.vh"

module top #( `FMCW_DEFAULT_PARAMS )
        (
         // clocks, resets, LEDs, connectors
         input wire             clk_i, /* 40MHz */
         output wire            led_o, /* Indicates packet sent between PC and FPGA. */
         inout wire [GPIOW-1:0] ext1_io, /* General-purpose I/O. */
         inout wire [GPIOW-1:0] ext2_io, /* General-purpose I/O. */

         // FT2232H USB interface.
         inout wire [USBDW-1:0] ft_data_io, /* FIFO data */
         input wire             ft_rxf_n_i, /* Low when there is data in the buffer that can be read. */
         input wire             ft_txe_n_i, /* Low when there is room for transmission data in the FIFO. */
         output wire            ft_rd_n_o, /* Drive low to load read data to ft_data_io each clock cycle. */
         output wire            ft_wr_n_o, /* Drive low to write ft_data_io to FIFO for transmission. */
         output wire            ft_siwua_n_o, /* Flush transmission data to USB immediately. */
         input wire             ft_clkout_i, /* 60MHz clock used to synchronize data transfers. */
         output wire            ft_oe_n_o, /* Drive low one period before ft_rd_n_o to signal read. */
         input wire             ft_suspend_n_i, /* Low when USB in suspend mode. */

         // ADC
         input wire [IW-1:0]    adc_d_i, /* Input data from ADC. */
         input wire [1:0]       adc_of_i, /* High value indicates overflow or underflow. */
         output reg [1:0]       adc_oe_o, /* 10 turns on channel A and turns off channel B. */
         output reg [1:0]       adc_shdn_o, /* Same state as adc_oe. */

         // SD card
         // TODO: Setup option to load bitstream from SD card.
         inout wire [SDDW-1:0]  sd_data_i,
         inout wire             sd_cmd_i,
         output reg             sd_clk_o,
         input wire             sd_detect_i,

         // mixer
         output reg             mix_enbl_n_o, /* Low voltage enables mixer. */

         // power amplifier
         output reg             pa_off_o,

         // frequency synthesizer
         output wire            adf_ce_o,
         output wire            adf_le_o,
         output wire            adf_clk_o,
         input wire             adf_muxout_i,
         output wire            adf_txdata_o,
         output wire            adf_data_o,
         input wire             adf_done_i,

         // flash memory
         // TODO: Configure flash to save bitstream configuration across boot cycles.
         output reg             flash_cs_n_o,
         input wire             flash_miso_i,
         output reg             flash_mosi_o
         );

        initial begin
                adc_oe_o = 2'b10;
                adc_shdn_o = 2'b10;
                sd_clk_o = 1'b0;
                mix_enbl_n_o = 1'b0;
                pa_off_o = 1'b0;
                flash_cs_n_o = 1'b1;
                flash_mosi_o = 1'b0;
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
        // assign ext1_io = {GPIOW{1'b0}};
        // assign ext2_io = {GPIOW{1'b0}};
        assign led_o = (!ft_rd_n_o || !ft_wr_n_o) ? 1'b1 : 1'b0;

        wire                    clk_downsampled;
        wire [OW-1:0]           data_downsampled;
        wire [OW-1:0]           data_filtered;
        wire [USBDW-1:0]        usb_rdata;
        wire [USBDW-1:0]        usb_wdata;

        fir fir (.clk(clk_i),
                 .rst(1),
                 .ce(1),
                 .data_i(adc_d_i),
                 .data_o(data_filtered));

        downsample downsample (.clk_i(clk_i),
                               .clk_o(clk_downsampled),
                               .data_i(data_filtered),
                               .data_o(data_downsampled));

        data_packer data_packer (.clk_i(clk_downsampled),
                                 .data_i(data_downsampled),
                                 .data_o(usb_wdata));

        usb usb (.data_io(ft_data_io),
                 .rdata_o(usb_rdata),
                 .wdata_i(usb_wdata),
                 .rxf_n_i(ft_rxf_n_i),
                 .txe_n_i(ft_txe_n_i),
                 .rd_n_o(ft_rd_n_o),
                 .wr_n_o(ft_wr_n_o),
                 .siwua_n_o(ft_siwua_n_o),
                 .clk_i(ft_clkout_i),
                 .oe_n_o(ft_oe_n_o),
                 .suspend_n_i(ft_suspend_n_i));

        adf4158 adf4158 (.clk_i(clk_i),
                         .ce_o(adf_ce_o),
                         .le_o(adf_le_o),
                         .clk_o(adf_clk_o),
                         .muxout_i(adf_muxout_i),
                         .txdata_o(adf_txdata_o),
                         .data_o(adf_data_o));

endmodule // top
