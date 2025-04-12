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
    parameter integer RADIOS = 32,
    localparam integer RSB = RADIOS - 1,

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

    localparam integer XBITS = LOOP0 * TRATE * $clog2(RADIOS),
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

    parameter  integer WIDTH = 11,
    localparam integer MSB   = WIDTH - 1,
    localparam integer WBITS = WIDTH * LOOP1,
    localparam integer WSB   = WBITS - 1,

    // Adder and accumulator bit-widths
    localparam integer ADDER = $clog2(LOOP0 + 1) + 1,
    localparam integer ACCUM = ADDER + $clog2(LOOP1 + 1)
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
    output vis_last_o,
    output [MSB:0] vis_rdata_o,
    output [MSB:0] vis_idata_o
);

  // -- State & Signals -- //

  wire [LENGTH:0] sig_valid_w, sig_first_w, sig_next_w, sig_emit_w, sig_last_w;
  wire [TBITZ+TSB:0] sig_addr_w;
  wire [RADIOS*LOOP1+RSB:0] sig_dati_w, sig_datq_w;

  wire [LSB:0] vis_frame_w, vis_valid_w, vis_first_w, vis_last_w;
  wire [WSB:0] vis_real_w, vis_imag_w;


  // -- Correlator-Chain Instances -- //

  genvar ii;
  generate
    for (ii = 0; ii < LOOP1; ii = ii + 1) begin : gen_vis_chains

      vischain #(
          .RADIOS(RADIOS),
          .MUX_N (MUX_N),
          .TRATE (TRATE),
          .ATAPS (ATAPS[(ii+1)*XBITS-1:ii*XBITS]),
          .BTAPS (BTAPS[(ii+1)*XBITS-1:ii*XBITS]),
          .ASELS (ASELS[(ii+1)*YBITS-1:ii*YBITS]),
          .BSELS (BSELS[(ii+1)*YBITS-1:ii*YBITS]),
          .AUTOS (AUTOS[(ii+1)*ZBITS-1:ii*ZBITS]),
          .LOOP0 (LOOP0),
          .LOOP1 (LOOP1)
      ) U_VC[ii] (
          .clock(clock),
          .reset(reset),

          .sig_valid_i(sig_valid_w[ii]),
          .sig_first_i(sig_first_w[ii]),
          .sig_next_i (sig_next_w[ii]),
          .sig_emit_i (sig_emit_w[ii]),
          .sig_last_i (sig_last_w[ii]),
          .sig_addr_i (sig_addr_w[ii*TBITS+TSB:ii*TBITS]),
          .sig_dati_i (sig_dati_w[ii*RADIOS+RSB:ii*RADIOS]),
          .sig_datq_i (sig_datq_w[ii*RADIOS+RSB:ii*RADIOS]),

          .sig_valid_o(sig_valid_w[ii+1]),
          .sig_first_o(sig_first_w[ii+1]),
          .sig_next_o (sig_next_w[ii+1]),
          .sig_emit_o (sig_emit_w[ii+1]),
          .sig_last_o (sig_last_w[ii+1]),
          .sig_addr_o (sig_addr_w[(ii+1)*TBITS+TSB:(ii+1)*TBITS]),
          .sig_dati_o (sig_dati_w[(ii+1)*RADIOS+RSB:(ii+1)*RADIOS]),
          .sig_datq_o (sig_datq_w[(ii+1)*RADIOS+RSB:(ii+1)*RADIOS]),

          .vis_frame_o(vis_frame_w[ii]),
          .vis_valid_o(vis_valid_w[ii]),
          .vis_first_o(vis_first_w[ii]),
          .vis_last_o (vis_last_w[ii]),
          .vis_real_o (vis_real_w[(ii+1)*WIDTH-1:ii*WIDTH]),
          .vis_imag_o (vis_imag_w[(ii+1)*WIDTH-1:ii*WIDTH])
      );

    end  // gen_vis_chains
  endgenerate


  // -- Daisy-Chain for Each of the Correlator-Chain Outputs -- //

  vismerge #(
      .LENGTH(LOOP1),
      .WIDTH (WIDTH)
  ) U_ROUTE1 (
      .clock(clock),
      .reset(reset),

      .par_valid_i(vis_first_w),
      .par_rdata_i(vis_real_w),
      .par_idata_i(vis_imag_w),

      .seq_valid_o(cor_valid),
      .seq_rdata_o(cor_real_w),
      .seq_idata_o(cor_imag_w)
  );


  // -- Accumulator for the Chain of Chains -- //

  // Note: this instance would normally be at the end of a `vismerge` "chain,"
  //   which would typically be `LOOP0` in length.
  visaccum #(
      .IBITS(ABITS),
      .OBITS(SBITS),
      .PSUMS(LOOP0),
      .COUNT(LOOP1)
  ) U_VISACC1 (
      .clock(vis_clock),
      .reset(vis_reset),

      .frame_i(cor_frame),
      .valid_i(cor_valid),
      .rdata_i(cor_revis),
      .idata_i(cor_imvis),

      .frame_o(vis_frame_o),
      .valid_o(vis_valid_o),
      .first_o(),
      .last_o (vis_last_o),
      .rdata_o(vis_rdata_o),
      .idata_o(vis_idata_o)
  );


endmodule  /* visblock */
