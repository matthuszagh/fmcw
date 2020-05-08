`ifndef _CONTROL_V_
`define _CONTROL_V_

`default_nettype none
`timescale 1ns/1ps

module control #(
   parameter FFT_N    = 10,
   parameter AVG_LG_N = 6
) (
   input wire clk,
   input wire rst_n,
   input wire adf_done,
   input wire ramp_start,
   input wire window_valid,
   input wire fifo_full,
   input wire fft_done,
   input wire ft245_empty,
   input wire clk_2mhz_pos_en,

   output reg adf_en,
   output reg fir_en,
   output reg fifo_wren,
   output reg fifo_rden,
   output reg fft_en
);

   localparam [2:0] ADF_CONFIG_STATE = 3'd0;
   localparam [2:0] FIR_STATE        = 3'd1;
   localparam [2:0] FIR_WAIT_STATE   = 3'd2;
   localparam [2:0] FFT_STATE        = 3'd3;
   localparam [2:0] FT245_STATE      = 3'd4;

   localparam DELAY_WIDTH = 15;
   localparam [$clog2(FFT_N)-1:0] FIR_CTR_CMP = FFT_N-1;
   localparam [AVG_LG_N-1:0] FIR_AVG_CTR_CMP = {AVG_LG_N{1'b1}};

   reg [2:0]  state;
   reg [$clog2(FFT_N)-1:0] fir_ctr;
   reg [AVG_LG_N-1:0]      fir_avg_ctr;

   reg fifo_rd_delay;
   always @(posedge clk) begin
      if (!rst_n) begin
         state         <= ADF_CONFIG_STATE;
         fifo_rd_delay <= 1'b0;
         fir_ctr       <= {$clog2(FFT_N){1'b0}};
         fir_avg_ctr   <= {AVG_LG_N{1'b0}};
      end else begin
         case (state)
         ADF_CONFIG_STATE:
           begin
              fifo_rd_delay <= 1'b0;
              if (adf_done && ramp_start) begin
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
                 if (clk_2mhz_pos_en) begin
                    if (fir_ctr == FIR_CTR_CMP) begin
                       fir_ctr <= {$clog2(FFT_N){1'b0}};
                       if (fir_avg_ctr == FIR_AVG_CTR_CMP) begin
                          fir_avg_ctr <= {AVG_LG_N{1'b0}};
                       end else begin
                          fir_avg_ctr <= fir_avg_ctr + 1'b1;
                          state       <= FIR_WAIT_STATE;
                       end
                    end else begin
                       fir_ctr <= fir_ctr + 1'b1;
                    end
                 end
              end
           end

         FIR_WAIT_STATE:
           begin
              if (ramp_start) begin
                 state <= FIR_STATE;
              end else begin
                 state <= FIR_WAIT_STATE;
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
              // if the ft245 fifo isn't empty by the time the ramp
              // start signal occurs, we'll wait a full ramp plus
              // delay (3ms) and try again.
              if (ramp_start && ft245_empty) begin
                 state <= FIR_STATE;
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

      FIR_WAIT_STATE:
        begin
           adf_en    = 1'b1;
           fir_en    = 1'b0;
           fifo_wren = 1'b0;
           fifo_rden = 1'b0;
           fft_en    = 1'b0;
        end

      FFT_STATE:
        begin
           adf_en    = 1'b1;
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
           adf_en    = 1'b1;
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
