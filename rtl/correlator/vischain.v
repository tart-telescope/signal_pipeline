`timescale 1ns / 100ps
/**
 * Chains together multiple correlator functional units.
 *
 * Note:
 *  - resource usage is O(n);
 *
 * Todo:
 *  - currently non-functioning, and just a "sketch" -- still relevant ??
 *
 */
module vischain #(
  parameter integer LENGTH = 3,
  parameter integer WIDTH = 7,
  localparam integer MSB = WIDTH - 1
) (
  input clock,
  input reset,

  // Loads new data from attached visibilities unit
  input load_i,
  input [MSB:0] re_i,
  input [MSB:0] im_i,

  // From preceding registers in the chain
  input valid_i,
  input [MSB:0] data_i,

  // To the following registers in the chain
  output valid_o,
  output [MSB:0] data_o
);

endmodule  // vischain
