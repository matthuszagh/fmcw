`ifndef _CONTROL_V_
`define _CONTROL_V_

`default_nettype none
`timescale 1ns/1ps

module control (
   input wire clk,
   input wire rst_n,
   input wire adf_done,
   input wire window_valid,
   input wire fifo_full,
   input wire fft_done,
   input wire ft245_empty,

   output reg adf_en,
   output reg fir_en,
   output reg fifo_wren,
   output reg fifo_rden,
   output reg fft_en
);

   localparam [1:0] ADF_CONFIG_STATE = 2'd0;
   localparam [1:0] FIR_STATE = 2'd1;
   localparam [1:0] FFT_STATE = 2'd2;
   localparam [1:0] FT245_STATE = 2'd3;

   localparam DELAY_WIDTH = 15;

   reg [1:0]  state;

   reg fifo_rd_delay;
   always @(posedge clk) begin
      if (!rst_n) begin
         state <= ADF_CONFIG_STATE;
         fifo_rd_delay <= 1'b0;
      end else begin
         case (state)
         ADF_CONFIG_STATE:
           begin
              fifo_rd_delay <= 1'b0;
              if (adf_done) begin
                 state <= FIR_STATE;
              end else begin
                 state <= ADF_CONFIG_STATE;
              end
           end

         FIR_STATE:
           begin
              fifo_rd_delay <= 1'b0;
              if (fifo_full) begin
                 state <= FFT_STATE;
              end else begin
                 state <= FIR_STATE;
              end
           end

         FFT_STATE:
           begin
              fifo_rd_delay <= 1'b1;
              if (fft_done) begin
                 state <= FT245_STATE;
              end else begin
                 state <= FFT_STATE;
              end
           end

         FT245_STATE:
           begin
              if (ft245_empty) begin
                 state  <= ADF_CONFIG_STATE;
              end else begin
                 state <= FT245_STATE;
              end
           end

         default:
            begin
               fifo_rd_delay <= 1'b0;
               state <= ADF_CONFIG_STATE;
            end
         endcase
      end
   end

   always @(*) begin
      case (state)
      ADF_CONFIG_STATE:
        begin
           adf_en    = 1'b1;
           fir_en    = 1'b0;
           fifo_wren = 1'b0;
           fifo_rden = 1'b0;
           fft_en    = 1'b0;
        end

      FIR_STATE:
        begin
           adf_en = 1'b1;
           fir_en = 1'b1;
           if (window_valid) begin
              fifo_wren = 1'b1;
           end else begin
              fifo_wren = 1'b0;
           end
           fifo_rden = 1'b0;
           fft_en    = 1'b0;
        end

      FFT_STATE:
        begin
           adf_en    = 1'b0;
           fir_en    = 1'b0;
           fifo_wren = 1'b0;
           fifo_rden = 1'b1;
           if (fifo_rd_delay) begin
              fft_en = 1'b1;
           end else begin
              fft_en = 1'b0;
           end
        end

      FT245_STATE:
        begin
           adf_en    = 1'b0;
           fir_en    = 1'b0;
           fifo_wren = 1'b0;
           fifo_rden = 1'b0;
           fft_en    = 1'b0;
        end

      default:
        begin
           adf_en    = 1'b1;
           fir_en    = 1'b0;
           fifo_wren = 1'b0;
           fifo_rden = 1'b0;
           fft_en    = 1'b0;
        end
      endcase
   end

endmodule
`endif
