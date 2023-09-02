`timescale 1ns / 100ps
module top_tb;

  localparam integer WIDTH = 32;
  localparam integer CORES = 18;
  localparam integer SRAMWORDS = 32;
  localparam integer COUNT = 15;

  localparam integer TRATE = 30;
  localparam integer TBITS = 5;
  localparam integer ADDR = 4;

  // The full visibilities accumulator has `ACCUM` bits, but the first-stage only
  // uses `SUMBITS`-wide adders.
  localparam integer ACCUM = 36;
  localparam integer SUMBITS = 6;
  localparam integer PBITS = SBITS - 2;
  localparam integer PSUMS = (1 << PBITS) - 1;

  /**
   *  System-wide signals.
   */
  reg reset_ni = 1'b0;
  reg sig_clock = 1'b1;
  reg vis_clock = 1'b1;

  always sig_clock <= #150 ~sig_clock;
  always vis_clock <= #5 ~vis_clock;

  initial begin : SIM_INIT
    #305 reset_ni <= 1'b1;

    #6000 $finish;
  end

  /**
   *  Correlator Under Test.
   */
  tart_correlator #(
      .ACCUM(ACCUM),
      .WIDTH(WIDTH),
      .CORES(CORES),
      .TRATE(TRATE),
      .TBITS(TBITS),
      .WORDS(SRAMWORDS),
      .COUNT(COUNT),
      .ADDR(ADDR),
      .SUMBITS(SUMBITS)
  ) CORRELATOR0 (  /*AUTOINST*/);

endmodule  // top_tb
