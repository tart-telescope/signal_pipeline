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
    // Number of (1-bit, IQ) signal sources
    parameter integer RADIOS = 32,
    localparam integer RSB = RADIOS - 1,

    // Time-multiplexing is used, so used to map from timeslice to MUX indices
    parameter integer MUX_N = 7,  // A- & B- MUX widths
    parameter integer TRATE = 30,  // Time-multiplexing rate
    localparam integer TBITS = $clog2(TRATE),  // Input MUX bits
    localparam integer TSB = TBITS - 1,

    // todo: produce these values using the 'generator' utility
    parameter unsigned [PSB:0] ATAPS = {PBITS{1'bx}},
    parameter unsigned [PSB:0] BTAPS = {PBITS{1'bx}},

    parameter unsigned [QSB:0] ASELS = {QBITS{1'bx}},
    parameter unsigned [QSB:0] BSELS = {QBITS{1'bx}},

    parameter unsigned [TSB:0] AUTOS = {TBITS{1'bx}},

    // Default is for the source signals to travel in the reverse direction,
    // relative to the partial-visibilities, as this saves two cycles of delay
    // (elements), per correlator-chain
    parameter integer REVERSE = 1,

    // Parameters that determine (max) chain -length and -number
    parameter  integer LOOP0  = 3,
    parameter  integer LOOP1  = 5,
    localparam integer LENGTH = LOOP0,

    // Adder and accumulator bit-widths
    localparam integer ADDER = $clog2(LOOP0 + 1) + 1,
    localparam integer ACCUM = ADDER + $clog2(LOOP1 + 1),
    localparam integer MSB   = ACCUM - 1
) (
    // Visibilities clock-domain
    input clock,
    input reset,

    // Upstream radio-signal inputs
    input sig_valid_i,
    input sig_first_i,
    input sig_next_i,
    input sig_emit_i,
    input sig_last_i,
    input [TSB:0] addr_i,
    input [RSB:0] sig_dati_i,
    input [RSB:0] sig_datq_i,

    // Delayed radio-signal outputs
    output sig_valid_o,
    output sig_first_o,
    output sig_next_o,
    output sig_emit_o,
    output sig_last_o,
    output [TSB:0] addr_o,
    output [RSB:0] sig_dati_o,
    output [RSB:0] sig_datq_o,

    // To next element of the accumulator chain
    output vis_frame_o,
    output vis_valid_o,
    output vis_first_o,
    output vis_last_o,
    output [MSB:0] vis_real_o,
    output [MSB:0] vis_imag_o
);

  localparam integer WBITS = LENGTH * ADDER;
  localparam integer WSB = WBITS - 1;


  // -- Global Signals -- //

  // Correlator routing
  wire [LSB:0] src_prev_w;
  wire [WSB:0] src_real_w, src_imag_w;
  wire [LSB:0] dst_frame_w, dst_next_w;
  wire [WSB:0] dst_real_w, dst_imag_w;

  // Correlator to accumulator routing
  wire [LSB:0] cor_frame, cor_valid;
  wire [WSB:0] cor_real_w, cor_imag_w;


  // -- Source-Signal Delay Unit -- //

  sigdelay #(
      .RADIOS (RADIOS),
      .REVERSE(REVERSE),
      .TRATE  (TRATE),
      .LOOP0  (LOOP0)
  ) U_DELAY1 (
      .clock(clock),

      .valid_i(sig_valid_i),  // Undelayed, source signals
      .first_i(sig_first_i),
      .next_i (sig_next_i),
      .emit_i (sig_emit_i),
      .last_i (sig_last_i),
      .addr_i (sig_addr_i),
      .sig_ii (sig_dati_i),
      .sig_qi (sig_datq_i),

      .valid_o(sig_valid_o),  // Delayed, output signals
      .first_o(sig_first_o),
      .next_o (sig_next_o),
      .emit_o (sig_emit_o),
      .last_o (sig_last_o),
      .addr_o (sig_addr_o),
      .sig_io (sig_dati_o),
      .sig_qo (sig_datq_o)
  );


  // -- Correlator Chain -- //

  // Parallel (i.e., in phase) source-signals go in, and the outputs are
  // daisy-chained together, so that they are sequential fed into the
  // accumulator.
  correlator #(
      .WIDTH(RADIOS),
      .ABITS(ADDER),
      .MUX_N(MUX_N),
      .TRATE(TRATE),
      .ATAPS(ATAPS),
      .BTAPS(BTAPS),
      .ASELS(ASELS),
      .BSELS(BSELS),
      .AUTOS(AUTOS)
  ) U_COREX[0:LENGTH-1] (
      .clock(clock),
      .reset(reset),

      .valid_i(sig_valid_i),
      .first_i(sig_first_i),
      .next_i (sig_next_i),
      .emit_i (sig_emit_i),
      .last_i (sig_last_i),
      .taddr_i(sig_addr_i),
      .idata_i(sig_dati_i),
      .qdata_i(sig_datq_i),

      .prevs_i(src_prev_w),
      .revis_i(src_real_w),
      .imvis_i(src_imag_w),

      .frame_o(dst_frame_w),
      .valid_o(dst_next_w),
      .revis_o(dst_real_w),
      .imvis_o(dst_imag_w)
  );


  // -- Outputs Daisy-Chain -- //

  vismerge #(
      .LENGTH(LENGTH),
      .WIDTH (ADDER)
  ) U_ROUTE1 (
      .next_i (dst_next_w),
      .real_i (dst_real_w),
      .imag_i (dst_imag_w),
      .prev_o (src_prev_w),
      .real_o (src_real_w),
      .imag_o (src_imag_w),
      .valid_o(cor_valid),
      .rdata_o(cor_real_w),
      .idata_o(cor_imag_w)
  );


  // -- Accumulator for Chain -- //

  assign cor_frame = dst_frame_w[LSB];

  visaccum #(
      .IBITS(ABITS),
      .OBITS(SBITS),
      .PSUMS(LOOP0),
      .COUNT(LOOP1)
  ) U_VISACC1 (
      .clock(clock),
      .reset(reset),

      .frame_i(cor_frame),
      .valid_i(cor_valid),
      .rdata_i(cor_real_w),
      .idata_i(cor_imag_w),

      .frame_o(vis_frame_o),
      .valid_o(vis_valid_o),
      .first_o(vis_first_o),
      .last_o (vis_last_o),
      .rdata_o(vis_real_o),
      .idata_o(vis_imag_o)
  );


endmodule  /* vischain */
