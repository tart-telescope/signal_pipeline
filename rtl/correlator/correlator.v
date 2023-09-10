`timescale 1ns / 100ps
// `include "tartcfg.v"

module correlator (
    clock_i,
    reset_ni,
    enable_i,

    idata_i,
    qdata_i,

    revis_i,
    imvis_i,

    revis_o,
    imvis_o,
    valid_o,
    ready_i
);

  // TODO:
  //  - figure out how to parameterise the input MUXs
  //  - 'sigsource.v' for input MUXs
  //  - 'viscalc.v' for first-stage correlation

  parameter integer WIDTH = 32;  // Number of antennas/signals
  parameter integer SBITS = 5;
  parameter integer COUNT = 15;  // Number of terms for partial sums
  parameter integer CBITS = 4;
  parameter integer XBITS = 3;  // Input MUX bits

  localparam integer MSB = WIDTH - 1;
  localparam integer SSB = SBITS - 1;
  localparam integer CSB = CBITS - 1;
  localparam integer XSB = XBITS - 1;
  localparam integer ABITS = CBITS + 2;
  localparam integer ASB = ABITS - 1;

  input clock_i;
  input reset_ni;
  input enable_i;

  input [MSB:0] idata_i;
  input [MSB:0] qdata_i;

  input [ASB:0] revis_i;  // Inputs of each stage are outputs of the previous
  input [ASB:0] imvis_i;

  output [ASB:0] revis_o;
  output [ASB:0] imvis_o;
  output valid_o;
  input ready_i;


  /**
   *  Select source signals for visibility calculations.
   */
  reg [MSB:0] idata, qdata;
  reg [MSB:0] idatb, qdatb;
  reg          first = 1'b1;
  reg  [CSB:0] count = {CBITS{1'b0}};
  wire [CSB:0] cnext = count + 1;

  // Input MUXs, using pre-calculated signal indices
  reg  [XSB:0] index = {XBITS{1'b0}};
  wire [SSB:0] sel_a = xpairs_a[index];
  wire [SSB:0] sel_b = xpairs_b[index];

  always @(posedge clock_i) begin
    if (!reset_ni) begin
      index <= {SBITS{1'b0}};
      count <= {CBITS{1'b0}};
      first <= 1'b1;
    end else if (enable_i) begin
      if (cnext == COUNT) begin
        count <= {CBITS{1'b0}};
        index <= src_a + 1;
        first <= 1'b1;
      end else begin
        count <= cnext;
        first <= 1'b0;
      end

      idata <= idata_i[sel_a];
      qdata <= qdata_i[sel_a];

      idatb <= idata_i[sel_b];
      qdatb <= qdata_i[sel_b];
    end
  end

  /**
   *  Calculation of visibilty partial-sums.
   */
  // todo:
  wire [1:0] re_calc = idata * idatb - qdata * qdatb;
  wire [1:0] im_calc = idata * qdatb + qdata * idatb;
  reg [ASB:0] re, im;

  always @(posedge clock_i) begin
    if (first) begin
      re <= re_calc;
      im <= im_calc;
    end else begin
      re <= re + re_calc;
      im <= im + re_calc;
    end
  end

  /**
   *  Output pipeline.
   */
  reg [ASB:0] revis, imvis;

  assign revis_o = revis;
  assign imvis_o = imvis;

  always @(posedge clock_i) begin
    if (!reset_ni) begin
      revis <= {ABITS{1'bx}};
      imvis <= {ABITS{1'bx}};
    end else if (enable_i) begin
      if (first) begin
        revis <= re;
        imvis <= im;
      end else begin
        revis <= revis_i;
        imvis <= imvis_i;
      end
    end
  end

endmodule  // correlator
