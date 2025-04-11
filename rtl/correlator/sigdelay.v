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

    // The inner-loop value determines the phasing, so that each correlator-
    // chain outputs their 'LOOP0'-length chunks in succession
    parameter  integer LOOP0 = 3,
    localparam integer DELAY = LOOP0 - 1,
    localparam integer DEPTH = 1 << $clog2(LOOP0)
) (
    input clock,  // Correlator clock domain

    // Undelayed, source signals
    input valid_i,
    input [RSB:0] sig_ii,
    input [RSB:0] sig_qi,

    // Delayed output signals
    output valid_o,
    output [RSB:0] sig_io,
    output [RSB:0] sig_qo
);

  shift_register #(
      .WIDTH(RADIOS + RADIOS + 1),
      .DEPTH(DEPTH)
  ) U_SRL1 (
      .clock (clock),
      .wren_i(1'b1),
      .addr_i(DELAY),
      .data_i({valid_i, sig_qi, sig_ii}),
      .data_o({valid_o, sig_qo, sig_io})
  );

endmodule  // sigdelay
