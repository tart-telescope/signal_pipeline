`timescale 1ns / 100ps
//
// Dummy radio module, using shift-registers to mimic 1-bit radio I/Q output.
//
// Parameter `ANT_NUM` is the "index" for the antenna; e.g., 7 (of 24), and is
// used to compute a starting-value for the LFSR.
//
module radio_dummy #(
    parameter integer ANT_NUM = 0
) (
    input clk16,
    input rst_n,
    input i1,
    input q1,
    output reg data_i,
    output reg data_q
);

  // Set up an LFSR to produce a PRN sequence and use the ANT_NUM as a starting value

  reg [10:1] i_LFSR = ANT_NUM + 1;
  reg [10:1] q_LFSR = ANT_NUM + 3;

  wire i_XNOR, q_XNOR;

  assign i_XNOR = i_LFSR[10] ^~ i_LFSR[7];
  assign q_XNOR = q_LFSR[10] ^~ q_LFSR[7];

  initial begin
    data_i = 0;
    data_q = 0;
  end

  always @(posedge clk16 or negedge rst_n) begin
    if (!rst_n) begin
      i_LFSR <= ANT_NUM + 1;
      q_LFSR <= ANT_NUM + 3;
    end else begin
      i_LFSR <= {i_LFSR[9:1], i_XNOR};
      q_LFSR <= {q_LFSR[9:1], q_XNOR};
      data_i <= i_LFSR[2];
      data_q <= q_LFSR[2];
    end
  end

`ifdef __icarus
  initial begin
    $display("Radio-I/Q-capture-register (dummy) instance: %d", ANT_NUM);
  end
`endif /* __icarus */

endmodule  /* radio_dummy */
