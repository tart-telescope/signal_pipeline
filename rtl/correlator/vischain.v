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

    parameter integer MUX_N = 7,  // A- & B- MUX widths
    parameter integer TRATE = 30, // Time-multiplexing rate

    // todo: produce these values using the 'generator' utility
    parameter unsigned [PSB:0] ATAPS = {PBITS{1'bx}},
    parameter unsigned [PSB:0] BTAPS = {PBITS{1'bx}},

    parameter unsigned [QSB:0] ASELS = {QBITS{1'bx}},
    parameter unsigned [QSB:0] BSELS = {QBITS{1'bx}},

    parameter unsigned [TSB:0] AUTOS = {TBITS{1'bx}},

    // Parameters that determine (max) chain -length and -number
    parameter  integer LOOP0  = 3,
    parameter  integer LOOP1  = 5,
    localparam integer LENGTH = LOOP0,

    // Adder and accumulator bit-widths
    localparam integer ADDER = $clog2(LOOP0 + 1) + 1,
    localparam integer ACCUM = ADDER + $clog2(LOOP1 + 1),
    localparam integer MSB   = ACCUM - 1
) (
    input clock,
    input reset,

    input valid_i,
    input [RSB:0] sig_ii,
    input [RSB:0] sig_qi,

    // Delayed output signals
    output valid_o,
    output [RSB:0] sig_io,
    output [RSB:0] sig_qo,

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

  // -- Global Signals -- //

  localparam integer SBITS = LENGTH * ACCUM;
  localparam integer CBITS = (LENGTH + 1) * ACCUM;

  wire [SBITS-1:0] adder_w;
  wire [CBITS-1:0] chain_w;


  // -- Source-Signal Delay Unit -- //

  sigdelay#(
      .RADIOS(RADIOS),
      .LOOP0 (LOOP0)
  ) U_DELAY1 (
      .clock(clock),

      .valid_i(valid_i),  // Undelayed, source signals
      .sig_ii(sig_ii),
      .sig_qi(sig_qi),

      .valid_o(valid_o),  // Delayed output signals
      .sig_io(sig_io),
      .sig_qo(sig_qo)
  );


  // -- Correlator Chain -- //

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

      .valid_i(buf_valid_w),
      .first_i(buf_first_w),
      .next_i (buf_next_w),
      .emit_i (buf_emit_w),
      .last_i (buf_last_w),
      .taddr_i(buf_taddr_w),
      .idata_i(buf_idata_w),
      .qdata_i(buf_qdata_w),

      .prevs_i(1'b0),
      .revis_i({ABITS{1'bx}}),
      .imvis_i({ABITS{1'bx}}),

      .frame_o(cor_frame),
      .valid_o(cor_valid),
      .revis_o(cor_revis),
      .imvis_o(cor_imvis)
  );


  // -- Accumulator for Chain -- //

  wire vis_frame, vis_valid, vis_first, vis_last;
  wire [SSB:0] vis_rdata, vis_idata;

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

      .frame_o(vis_frame),
      .valid_o(vis_valid),
      .first_o(vis_first),
      .last_o (vis_last),
      .rdata_o(vis_rdata),
      .idata_o(vis_idata)
  );


endmodule  // vischain
