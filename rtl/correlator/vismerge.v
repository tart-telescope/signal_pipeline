`timescale 1ns / 100ps
/**
 * Merge parallel outputs into a daisy-chain of values.
 *
 * Note:
 *  - just the routing, and generic enough to be reusable;
 *
 * Todo:
 *  - currently non-functioning, and just a "sketch" -- still relevant ??
 *
 */
module vismerge #(
    parameter integer LENGTH = 3,
    parameter integer LSB = LENGTH - 1,
    parameter integer WIDTH = 7,
    localparam integer MSB = WIDTH - 1,
    localparam integer WBITS = LENGTH * WIDTH,
    localparam integer WSB = WBITS - 1,
    localparam integer PBITS = WBITS - LENGTH,
    localparam integer PSB = PBITS - 1
) (
    // From (parallel) outputs of correlators
    input [LSB:0] next_i,
    input [WSB:0] real_i,
    input [WSB:0] imag_i,

    // To (parallel) inputs of correlators
    output [LSB:0] prev_o,
    output [WSB:0] real_o,
    output [WSB:0] imag_o,

    // Daisy-chain outputs
    output valid_o,
    output rdata_o,
    output [MSB:0] idata_o
);


  assign prev_o  = {next_i[LENGTH-2:0], 1'b0};  // Todo: reverse-chaining!?
  assign real_o  = {real_i[PSB:0], {WIDTH{1'bx}}};
  assign imag_o  = {imag_i[PSB:0], {WIDTH{1'bx}}};

  assign valid_o = next_i[LSB];
  assign rdata_o = real_i[WSB:PBITS];
  assign idata_o = imag_i[WSB:PBITS];


endmodule  // vismerge
