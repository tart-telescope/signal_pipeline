`timescale 1ns / 100ps
/**
 * Merge parallel outputs into a daisy-chain of values.
 *
 * Note:
 *  - just a 2:1 MUX plus followed by an output register, for each daisy-chain
 *    element;
 *  - generic enough to be reusable, though the ports need to be made more
 *    general-purpose;
 *
 * Todo:
 *  - make into a general-purpose module;
 *
 */
module visblock #(
    // Number of (1-bit, IQ) signal sources
    parameter  integer CHANS = 32,
    localparam integer RSB   = CHANS - 1,

    // Time-multiplexing is used, so used to map from timeslice to MUX indices
    parameter integer MUX_N = 7,  // A- & B- MUX widths
    parameter integer TRATE = 30,  // Time-multiplexing rate
    localparam integer TBITS = $clog2(TRATE),  // Input MUX bits
    localparam integer TSB = TBITS - 1,
    localparam integer TBITZ = TBITS * LOOP1,

    // Number and layout of correlators
    parameter integer LOOP0 = 3,  // typ. 'LOOP1' in parent module
    parameter integer LOOP1 = 5,  // typ. 'LOOP1' in parent module
    parameter integer LENGTH = LOOP1,  // typ. 'LOOP1' in parent module
    parameter integer LSB = LENGTH - 1,

    localparam integer XBITS = LOOP0 * MUX_N * $clog2(CHANS),
    localparam integer XBITZ = LOOP1 * XBITS,
    localparam integer YBITS = LOOP0 * TRATE * $clog2(MUX_N),
    localparam integer YBITZ = LOOP1 * YBITS,
    localparam integer ZBITS = LOOP0 * TRATE,
    localparam integer ZBITZ = LOOP1 * ZBITS,

    // todo: produce these values using the 'generator' utility
    parameter unsigned [XBITZ-1:0] ATAPS = {XBITZ{1'bx}},
    parameter unsigned [XBITZ-1:0] BTAPS = {XBITZ{1'bx}},

    parameter unsigned [YBITZ-1:0] ASELS = {YBITZ{1'bx}},
    parameter unsigned [YBITZ-1:0] BSELS = {YBITZ{1'bx}},

    parameter unsigned [ZBITZ-1:0] AUTOS = {ZBITZ{1'bx}},

    // Adder and accumulator bit-widths
    localparam integer ADDER = $clog2(LOOP0) + 2,
    localparam integer ACCUM = ADDER + $clog2(LOOP1),

    localparam integer PSUMS = LOOP0 * LOOP1,
    localparam integer ASB   = ACCUM - 1,
    localparam integer SBITS = ACCUM + $clog2(TRATE),
    localparam integer MSB   = SBITS - 1,
    localparam integer WBITS = SBITS * LOOP1,
    localparam integer WSB   = WBITS - 1
) (
    input clock,
    input reset,

    // Radio-signal inputs from 'sigbuffer'
    input sig_valid_i,
    input sig_first_i,
    input sig_next_i,
    input sig_emit_i,
    input sig_last_i,
    input [TSB:0] sig_addr_i,
    input [RSB:0] sig_dati_i,
    input [RSB:0] sig_datq_i,

    // Daisy-chained outputs from the 'visaccum' cores
    output vis_frame_o,
    output vis_valid_o,
    output vis_first_o,
    output vis_last_o,
    output [MSB:0] vis_rdata_o,
    output [MSB:0] vis_idata_o
);

  // -- State & Signals -- //

  wire [LENGTH:0] sig_valid_w, sig_first_w, sig_next_w, sig_emit_w, sig_last_w;
  wire [TBITZ+TSB:0] sig_addr_w;
  wire [CHANS*LOOP1+RSB:0] sig_dati_w, sig_datq_w;

  wire [LSB:0] vis_frame_w, vis_valid_w, vis_first_w, vis_last_w;
  wire [LENGTH*ACCUM-1:0] vis_real_w, vis_imag_w;

  wire cor_frame_w, cor_valid_w;
  wire [ASB:0] cor_real_w, cor_imag_w, cor_revis, cor_imvis;


  // -- Correlator-Chain Instances -- //

  assign sig_valid_w[0] = sig_valid_i;
  assign sig_first_w[0] = sig_first_i;
  assign sig_next_w[0] = sig_next_i;
  assign sig_emit_w[0] = sig_emit_i;
  assign sig_last_w[0] = sig_last_i;
  assign sig_addr_w[TSB:0] = sig_addr_i;
  assign sig_dati_w[RSB:0] = sig_dati_i;
  assign sig_datq_w[RSB:0] = sig_datq_i;

  genvar ii;
  generate
    for (ii = 0; ii < LOOP1; ii = ii + 1) begin : gen_vis_chains

      vischain #(
          .CHANS(CHANS),
          .ADDER(ADDER),
          .MUX_N(MUX_N),
          .TRATE(TRATE),
          .ATAPS(ATAPS[(ii+1)*XBITS-1:ii*XBITS]),
          .BTAPS(BTAPS[(ii+1)*XBITS-1:ii*XBITS]),
          .ASELS(ASELS[(ii+1)*YBITS-1:ii*YBITS]),
          .BSELS(BSELS[(ii+1)*YBITS-1:ii*YBITS]),
          .AUTOS(AUTOS[(ii+1)*ZBITS-1:ii*ZBITS]),
          .LOOP0(LOOP0),
          .LOOP1(LOOP1)
      ) U_XCHAIN (
          .clock(clock),
          .reset(reset),

          .sig_valid_i(sig_valid_w[ii]),
          .sig_first_i(sig_first_w[ii]),
          .sig_next_i (sig_next_w[ii]),
          .sig_emit_i (sig_emit_w[ii]),
          .sig_last_i (sig_last_w[ii]),
          .sig_addr_i (sig_addr_w[ii*TBITS+TSB:ii*TBITS]),
          .sig_dati_i (sig_dati_w[ii*CHANS+RSB:ii*CHANS]),
          .sig_datq_i (sig_datq_w[ii*CHANS+RSB:ii*CHANS]),

          .sig_valid_o(sig_valid_w[ii+1]),
          .sig_first_o(sig_first_w[ii+1]),
          .sig_next_o (sig_next_w[ii+1]),
          .sig_emit_o (sig_emit_w[ii+1]),
          .sig_last_o (sig_last_w[ii+1]),
          .sig_addr_o (sig_addr_w[(ii+1)*TBITS+TSB:(ii+1)*TBITS]),
          .sig_dati_o (sig_dati_w[(ii+1)*CHANS+RSB:(ii+1)*CHANS]),
          .sig_datq_o (sig_datq_w[(ii+1)*CHANS+RSB:(ii+1)*CHANS]),

          .vis_frame_o(vis_frame_w[ii]),
          .vis_valid_o(vis_valid_w[ii]),
          .vis_first_o(vis_first_w[ii]),
          .vis_last_o (vis_last_w[ii]),
          .vis_real_o (vis_real_w[(ii+1)*ACCUM-1:ii*ACCUM]),
          .vis_imag_o (vis_imag_w[(ii+1)*ACCUM-1:ii*ACCUM])
      );

    end  // gen_vis_chains
  endgenerate


  // -- Daisy-Chain for Each of the Correlator-Chain Outputs -- //

  vismerge #(
      .LENGTH (LOOP1),
      .REVERSE(1),
      .WIDTH  (ACCUM)
  ) U_ROUTE1 (
      .clock(clock),
      .reset(reset),

      .par_valid_i(vis_valid_w),
      .par_rdata_i(vis_real_w),
      .par_idata_i(vis_imag_w),

      .seq_valid_o(cor_valid_w),
      .seq_rdata_o(cor_real_w),
      .seq_idata_o(cor_imag_w)
  );


  // -- Accumulator for the Chain of Chains -- //

  // Note: only correct when chain is fully-saturated
  assign cor_frame_w = cor_valid_w;

  // Note: this instance would normally be at the end of a `vismerge` "chain,"
  //   which would typically be `LOOP0` in length.
  visaccum #(
      .IBITS(ACCUM),
      .OBITS(SBITS),
      .PSUMS(PSUMS),
      .COUNT(TRATE)
  ) U_VISACC1 (
      .clock(clock),
      .reset(reset),

      .frame_i(cor_frame_w),
      .valid_i(cor_valid_w),
      .rdata_i(cor_real_w),
      .idata_i(cor_imag_w),

      .frame_o(vis_frame_o),
      .valid_o(vis_valid_o),
      .first_o(vis_first_o),  // todo: will generate a "chunk" of firsts !?
      .last_o (vis_last_o),
      .rdata_o(vis_rdata_o),
      .idata_o(vis_idata_o)
  );


endmodule  /* visblock */
