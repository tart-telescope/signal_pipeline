`timescale 1ns / 100ps
module tart_correlator (  /*AUTOARG*/);

  parameter integer WIDTH = 32; // Number of antennas/signals
  parameter integer CORES = 18; // Number of correlator cores
  parameter integer ACCUM = 36; // Bit-width of accumulators

  parameter integer WORDS = 32; // Buffer SRAM size
  parameter integer COUNT = 15; // Number of terms for partial sums

  // Time-multiplexing rate; i.e., clock multiplier
  parameter integer TRATE = 30;
  parameter integer TBITS = 5;

  parameter integer ADDR = 4;
  parameter integer SUMBITS = 6;

  localparam integer CSB = CORES - 1;
  localparam integer MSB = WIDTH - 1;
  localparam integer TSB = TBITS - 1;
  localparam integer ASB = ADDR - 1;
  localparam integer SSB = SUMBITS - 1;

  input sig_clock;
  input vis_clock;
  input reset_ni;
  input enable_i;

  input [MSB:0] idata_i;
  input [MSB:0] qdata_i;

  output start_o;
  output frame_o;
  output [SSB:0] revis_o;
  output [SSB:0] imvis_o;

  /**
   *  Input buffering SRAM's for signal IQ data.
   */
  reg          wbank = 1'b0;
  reg  [ASB:0] waddr = {ADDR{1'b0}};
  wire [ASB:0] wnext = waddr + 1;
  reg          ready = 1'b0;

  reg  [MSB:0] isram                [WORDS];
  reg  [MSB:0] qsram                [WORDS];

  always @(posedge sig_clock) begin
    // Signal address unit
    if (!reset_ni) begin
      waddr <= {ADDR{1'b0}};
      wbank <= 1'b0;
      ready <= 1'b0;
    end else begin
      if (wnext < COUNT) begin
        waddr <= waddr_next;
        ready <= 1'b0;
      end else begin
        waddr <= {ADDR{1'b0}};
        wbank <= ~wbank;
        ready <= 1'b1;
      end
    end

    // Store incoming data
    if (enable) begin
      isram[{wbank, waddr}] <= idata_i;
      qsram[{wbank, waddr}] <= qdata_i;
    end
  end

  /**
   *  When a new bank of signal data is ready, start a new visibility calculation.
   */
  reg start = 1'b0;
  reg fired = 1'b0;

  always @(posedge vis_clock) begin
    if (!reset_ni) begin
      start <= 1'b0;
      fired <= 1'b0;
    end else begin
      start <= ready & ~fired;
      fired <= ready;
    end
  end

  /**
   *  Output of SRAM IQ data to the correlators.
   */
  reg          rbank = 1'b0;
  reg  [ASB:0] raddr = {ADDR{1'b0}};
  wire [ASB:0] rnext = raddr + 1;
  reg          frame = 1'b0;

  reg  [TSB:0] times = {TBITS{1'b0}};
  wire [TSB:0] tnext = times + 1;

  assign start_o = start;
  assign frame_o = frame;

  always @(posedge vis_clock) begin
    if (!reset_ni) begin
      raddr <= {ADDR{1'b0}};
      rbank <= 1'b0;
      frame <= 1'b0;
      times <= {TRATE{1'b0}};
    end else begin
      if (ready & ~fired) begin
        frame <= 1'b1;
      end else if (rnext == COUNT) begin
        raddr <= {ADDR{1'b0}};
        if (tnext == TRATE) begin
          frame <= 1'b0;
          rbank <= ~rbank;
        end
      end

      if (frame) begin
        raddr <= raddr_next;
      end else begin
        raddr <= {ADDR{1'b0}};
      end
    end
  end

  always @(posedge vis_clock) begin
    if (frame) begin
      idata <= isram[{rbank, raddr}];
      qdata <= qsram[{rbank, raddr}];
    end
  end

  // todo:
  assign revis_o = idata;
  assign imvis_o = qdata;

  correlator #(
      .WIDTH(WIDTH),
      .COUNT(COUNT),
      .ADDR (ADDR)
  ) CORR[CORES] (  /*AUTOINST*/);

  /**
   *  Accumulates each of the partial-sums into the full-width visibilities.
   */

  // Total number of sums (though not all of them may be used)
  localparam integer TOTAL = CORES * TRATE;

  accumulator #(
      .WIDTH(ACCUM),
      .TOTAL(TOTAL)
  ) ACCUM0 (  /*AUTOINST*/);

endmodule  // tart_correlator
