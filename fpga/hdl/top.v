`default_nettype none

`include "fmcw_defines.vh"

module top #( `FMCW_DEFAULT_PARAMS )
        (
         // clocks, resets, LEDs, connectors
         input wire          clk, /* 40MHz */
         output reg          led,
         output reg [5:0]    ext1,
         output reg [5:0]    ext2,

         // FT2232H
         inout wire          ft_data,
         input wire          ft_rxf,
         input wire          ft_txe,
         output reg          ft_rd,
         output reg          ft_wr,
         output reg          ft_siwua,
         input wire          ft_clkout,
         output reg          ft_oe,
         input wire          ft_suspend,

         // ADC
         input wire [IW-1:0] adc_d,
         input wire [1:0]    adc_of,
         output reg [1:0]    adc_oe,
         output reg [1:0]    adc_shdn,

         // SD card
         inout wire [3:0]    sd_data,
         inout wire          sd_cmd,
         output reg          sd_clk,
         input wire          sd_detect,

         // mixer
         output reg          mix_enbl,

         // power amplifier
         output reg          pa_off,

         // frequency synthesizer
         output reg          adf_ce,
         output reg          adf_le,
         output reg          adf_clk,
         input wire          adf_muxout,
         output reg          adf_txdata,
         output reg          adf_data,
         input wire          adf_done,

         // flash memory
         output reg          spi_cs,
         input wire          spi_din,
         output reg          spi_dout
         );

        wire                 clk_adc;
        wire                 data_o;
        wire [OW-1:0]        data_fir_o;

        fir fir (.clk(clk),
                 .rst(1),
                 .ce(1),
                 .data_i(adc_d),
                 .data_o(data_fir_o));

        downsample downsample (.clk_i(clk_i),
                               .clk_o(clk_adc),
                               .data_i(data_fir_o),
                               .data_o(data_o));

endmodule // top
