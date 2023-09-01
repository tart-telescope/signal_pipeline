`timescale 1ns / 100ps
module top_tb;

  localparam integer ACCUM = 36;
  localparam integer WIDTH = 32;
  localparam integer CORES = 18;
  localparam integer SRAMWORDS = 32;
  localparam integer COUNT = 15;
  localparam integer TRATE = 30;
  localparam integer ADDR = 4;

  tart_correlator #(
      .ACCUM(ACCUM),
      .WIDTH(WIDTH),
      .CORES(CORES),
      .WORDS(SRAMWORDS),
      .COUNT(COUNT),
      .ADDR(ADDR),
      .SUMBITS(SUMBITS)
  ) CORRELATOR0 (  /*AUTOINST*/);

endmodule  // top_tb
