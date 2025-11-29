`timescale 1ns / 100ps
// Basic input module from a Max2769 set up for TART3 with single bit I and Q
// This will need a bit of tweaking in real life in order to get the sampling to happen when the external data is valid. 
// As the data is clocked at 8 MHz on the output, I suspect we can just use negedge to get something reasonable (after checking with an oscilloscope).
module radio #(
    parameter integer ANT_NUM = 0
) (
    input clk16,
    input rst_n,
    input i1,
    input q1,
    output reg data_i,
    output reg data_q
);

  initial begin
    data_i <= 0;
    data_q <= 0;
  end

  always @(posedge clk16 or negedge rst_n) begin
    if (!rst_n) begin
      data_i <= 0;
      data_q <= 0;
    end else begin
      data_i <= i1;
      data_q <= q1;
    end
  end

`ifdef __icarus
  initial begin
    $display("Radio-I/Q-capture-register instance: %d", ANT_NUM);
  end
`endif /* __icarus */

endmodule  /* radio */
