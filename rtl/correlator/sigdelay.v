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
    localparam integer DBITS = $clog2(DELAY + 1),
    localparam integer DSB   = DBITS - 1,
    localparam integer DEPTH = 1 << DBITS
) (
    input clock,  // Correlator clock domain
    input reset,

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

  generate
    if (DELAY > 1) begin : gen_shifts

      wire [DSB:0] delay_w = DELAY[DSB:0] - 2;

      shift_register #(
          .WIDTH(RADIOS + RADIOS + TBITS + 5),
          .DEPTH(DEPTH)
      ) U_SRL1 (
          .clock (clock),
          .wren_i(1'b1),
          .addr_i(delay_w),
          .data_i({addr_i, last_i, emit_i, next_i, first_i, valid_i, sigq_i, sigi_i}),
          .data_o({addr_o, last_o, emit_o, next_o, first_o, valid_o, sigq_o, sigi_o})
      );

    end  // gen_shifts
    else if (DELAY > 0) begin : gen_a_shift

      reg valid_q, first_q, next_q, emit_q, last_q;
      reg [TSB:0] addr_q;
      reg [RSB:0] sigi_q, sigq_q;

      assign valid_o = valid_q;
      assign first_o = first_q;
      assign next_o  = next_q;
      assign emit_o  = emit_q;
      assign last_o  = last_q;
      assign addr_o  = addr_q;
      assign sigi_o  = sigi_q;
      assign sigq_o  = sigq_q;

      always @(posedge clock) begin
        if (reset) begin
          valid_q <= 1'b0;
          first_q <= 1'b0;
          next_q  <= 1'b0;
          emit_q  <= 1'b0;
          last_q  <= 1'b0;
          addr_q  <= 'bx;
          sigi_q  <= 'bx;
          sigq_q  <= 'bx;
        end else begin
          valid_q <= valid_i;
          first_q <= first_i;
          next_q  <= next_i;
          emit_q  <= emit_i;
          last_q  <= last_i;
          addr_q  <= addr_i;
          sigi_q  <= sigi_i;
          sigq_q  <= sigq_i;
        end
      end

    end  // gen_a_shift
    else begin : gen_no_shift

      assign valid_o = valid_i;
      assign first_o = first_i;
      assign next_o  = next_i;
      assign emit_o  = emit_i;
      assign last_o  = last_i;
      assign addr_o  = addr_i;
      assign sigi_o  = sigi_i;
      assign sigq_o  = sigq_i;

    end  // gen_no_shift
  endgenerate

endmodule  /* sigdelay */
