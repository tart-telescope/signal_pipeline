`timescale 1ns / 100ps
module sigsource (  /*AUTOARG*/);

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

  // Interleaved, AXI4-Stream like antenna IQ source-data inputs
  input valid_i;
  input first_i;
  input last_i;
  input [MSB:0] idata_i;
  input [MSB:0] qdata_i;

  // Output IQ, A- & B- signals to the correlator
  output valid_o;
  output first_o;
  output last_o;
  output ai_o;
  output aq_o;
  output bi_o;
  output bq_o;

endmodule  // sigsource
