`timescale 1ns / 100ps
/**
 * Shift-register elements for delaying the raw radio signals (but delayed by
 * 'DELAY' cycles in the correlator clock-domain).
 *
 * Note:
 *  - resource usage is either O(n) shift-registers, or O(n.m) DFFs, where 'm'
 *    is the delay amount;
 *  - correlator clock domain;
 */
module sigdelay #(
    // Number of (1-bit, IQ) signal sources
    parameter integer RADIOS = 32,
    localparam integer RSB = RADIOS - 1,

    // Default is for the source signals to travel in the reverse direction,
    // relative to the partial-visibilities, as this saves two cycles of delay
    // (elements), per correlator-chain
    parameter integer REVERSE = 1,

    // Time-multiplexing is used, so used to map from timeslice to MUX indices
    parameter  integer TRATE = 30,
    localparam integer TBITS = $clog2(TRATE),  // Input MUX bits
    localparam integer TSB   = TBITS - 1,

    // The inner-loop value determines the phasing, so that each correlator-
    // chain outputs their 'LOOP0'-length chunks in succession
    parameter  integer LOOP0 = 3,
    localparam integer DELAY = REVERSE == 1 ? LOOP0 - 1 : LOOP0 + 1,
    localparam integer DEPTH = 1 << $clog2(DELAY)
) (
    input clock,  // Correlator clock domain

    // Undelayed, source signals
    input valid_i,
    input first_i,
    input next_i,
    input emit_i,
    input last_i,
    input [TSB:0] addr_i,
    input [RSB:0] sigi_i,
    input [RSB:0] sigq_i,

    // Delayed output signals
    output valid_o,
    output first_o,
    output next_o,
    output emit_o,
    output last_o,
    output [TSB:0] addr_o,
    output [RSB:0] sigi_o,
    output [RSB:0] sigq_o
);

  shift_register #(
      .WIDTH(RADIOS + RADIOS + TBITS + 5),
      .DEPTH(DEPTH)
  ) U_SRL1 (
      .clock (clock),
      .wren_i(1'b1),
      .addr_i(DELAY),
      .data_i({addr_i, last_i, emit_i, next_i, first_i, valid_i, sigq_i, sigi_i}),
      .data_o({addr_o, last_o, emit_o, next_o, first_o, valid_o, sigq_o, sigi_o})
  );

endmodule  // sigdelay
