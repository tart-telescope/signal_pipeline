`timescale 1ns / 100ps
// `include "tartcfg.v"

module correlator (
    clock,
    reset_n,

    valid_i,
    first_i,
    next_i,
    last_i,
    taddr_i,
    idata_i,
    qdata_i,

    prevs_i,
    revis_i,
    imvis_i,

    revis_o,
    imvis_o,
    valid_o,
    first_o,
    last_o
);

  // TODO:
  //  - figure out how to parameterise the input MUXs
  //  - 'sigsource.v' for input MUXs
  //  - 'viscalc.v' for first-stage correlation

  parameter integer WIDTH = 32;  // Number of antennas/signals
  parameter integer SBITS = 5;
  parameter integer ABITS = 4;  // Adder bit-width

  parameter integer XBITS = 3;  // Input MUX bits
  parameter integer MUX_N = 7;

  parameter integer TRATE = 30;  // Time-multiplexing rate
  parameter integer TBITS = 5;

  localparam integer MSB = WIDTH - 1;
  localparam integer XSB = XBITS - 1;
  localparam integer TSB = TBITS - 1;
  localparam integer ASB = ABITS - 1;

  localparam integer PBITS = SBITS * MUX_N;  // Signal taps for A-/B- MUX inputs
  localparam integer PSB = PBITS - 1;

  localparam integer QBITS = TRATE * XBITS;  // Time-interval to MUX-sel bits
  localparam integer QSB = QBITS - 1;

  // todo: produce these values using the 'generator' utility
  parameter unsigned [PSB:0] ATAPS = {PBITS{1'bx}};
  parameter unsigned [PSB:0] BTAPS = {PBITS{1'bx}};

  parameter unsigned [QSB:0] ASELS = {QBITS{1'bx}};
  parameter unsigned [QSB:0] BSELS = {QBITS{1'bx}};


  input clock;
  input reset_n;

  input valid_i;
  input first_i;
  input next_i;
  input last_i;
  input [TSB:0] taddr_i;
  input [MSB:0] idata_i;
  input [MSB:0] qdata_i;

  input prevs_i;
  input [ASB:0] revis_i;  // Inputs of each stage are outputs of the previous
  input [ASB:0] imvis_i;

  output [ASB:0] revis_o;
  output [ASB:0] imvis_o;
  output valid_o;
  output first_o;
  output last_o;


  // -- Pipelined control-signals -- //

  reg last, next, valid;

  always @(posedge clock) begin
    if (!reset_n) begin
      valid <= 1'b0;
      last  <= 1'b0;
      next  <= 1'b0;
    end else begin
      valid <= valid_i;

      if (valid) begin
        last <= next_i;
        next <= last;
      end else begin
        last <= 1'b0;
        next <= 1'b0;
      end
    end
  end


  // -- Antenna signal source-select -- //

  wire mux_valid;
  wire mux_ai, mux_aq, mux_bi, mux_bq;

  sigsource #(
      .WIDTH(WIDTH),
      .SBITS(SBITS),
      .XBITS(XBITS),
      .MUX_N(MUX_N),
      .TRATE(TRATE),
      .TBITS(TBITS),
      .ATAPS(ATAPS),
      .BTAPS(BTAPS),
      .ASELS(ASELS),
      .BSELS(BSELS)
  ) SIGSRC0 (
      .clock(clock),
      .reset_n(reset_n),
      // Inputs
      .valid_i(valid_i),
      .first_i(first_i),
      .last_i(last_i),
      .taddr_i(taddr_i),
      .idata_i(idata_i),
      .qdata_i(qdata_i),
      // Outputs
      .valid_o(mux_valid),
      .first_o(),
      .last_o(),
      .ai_o(mux_ai),
      .aq_o(mux_aq),
      .bi_o(mux_bi),
      .bq_o(mux_bq)
  );


  // -- Cross-correlator -- //

  wire auto = 1'b0; // todo: ...
  wire cor_valid;
  wire [ASB:0] cor_revis, cor_imvis;

  correlate #(
      .WIDTH(ABITS)
  ) CORRELATE0 (
      .clock(clock),
      .reset_n(reset_n),
      // Inputs
      .valid_i(mux_valid),
      .first_i(next),
      .last_i(last),
      .auto_i(auto),
      .ai_i(mux_ai),
      .aq_i(mux_aq),
      .bi_i(mux_bi),
      .bq_i(mux_bq),
      // Outputs
      .valid_o(cor_valid),
      .re_o(cor_revis),
      .im_o(cor_imvis)
  );


  // -- Output select & pipeline -- //

  reg succs;
  reg [ASB:0] revis, imvis;

  assign valid_o = succs;
  assign first_o = 1'bx;  // todo: ...
  assign last_o  = 1'bx;  // todo: ...
  assign revis_o = revis;
  assign imvis_o = imvis;

  always @(posedge clock) begin
    if (!reset_n) begin
      succs <= 1'b0;
      revis <= {ABITS{1'bx}};
      imvis <= {ABITS{1'bx}};
    end else begin
      succs <= cor_valid | prevs_i;

      if (cor_valid) begin
        revis <= cor_revis;
        imvis <= cor_imvis;
      end else begin
        revis <= revis_i;
        imvis <= imvis_i;
      end
    end
  end

endmodule  // correlator
