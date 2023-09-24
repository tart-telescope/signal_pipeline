`timescale 1ns / 100ps
/**
 * Input-buffering SRAM's for (antenna) signal IQ data.
 *
 * Every 'COUNT' input samples a full set of (partially-summed) visibility
 * contributions are computed, and forwarded to the final-stage accumulators.
 * The following buffer stores two (or more) banks of these 'COUNT' samples,
 * and streams them (with the correct ordering) to the correlators, switching
 * banks at the end of each block (of 'COUNT' samples).
 */
module sigbuffer (  /*AUTOARG*/
    sig_clk,
    vis_clk,
    reset_n,
    // Outputs
    valid_o,
    first_o,
    last_o,
    taddr_o,
    idata_o,
    qdata_o,
    // Inputs
    valid_i,
    idata_i,
    qdata_i
);

  // Number of antennas/sources
  parameter integer WIDTH = 32;
  localparam integer MSB = WIDTH - 1;

  // Time-multiplexing is used, so used to map from timeslice to MUX indices
  parameter integer TRATE = 30;
  // parameter integer TBITS = 5;  // Input MUX bits
  localparam integer TBITS = $clog2(TRATE);  // Input MUX bits
  localparam integer TSB = TBITS - 1;

  // For each antenna-pair, partial (visibility) sums are computed from COUNT
  // cross-correlations
  parameter integer COUNT = 15;
  // parameter integer CBITS = 4;
  localparam integer CBITS = $clog2(COUNT);
  localparam integer CSB = CBITS - 1;

  // At least two banks are required, so that one can be filled, while the other
  // is being read
  parameter integer BBITS = 1;
  localparam integer BANKS = 1 << BBITS;

  // SRAM address and size parameters
  localparam integer WORDS = 1 << (CBITS + BBITS);
  localparam integer ABITS = CBITS + BBITS;
  localparam integer ASB = ABITS - 1;

  input sig_clk;
  input vis_clk;
  input reset_n;

  // Antenna source signal domain
  input valid_i;
  input [MSB:0] idata_i;
  input [MSB:0] qdata_i;

  // Correlator clock domain
  output valid_o;
  output first_o;
  output last_o;
  output [TSB:0] taddr_o;
  output [MSB:0] idata_o;
  output [MSB:0] qdata_o;


  // -- Capture of antenna IQ signals -- //

  reg [MSB:0] isram[WORDS];
  reg [MSB:0] qsram[WORDS];
  reg [ASB:0] waddr;
  reg switch;

  wire [ASB:0] wnext = waddr + 1;
  wire [ASB:CBITS] wbank = waddr[ASB:CBITS] + 1;

  always @(posedge sig_clk) begin
    if (!reset_n) begin
      waddr  <= {ABITS{1'b0}};
      switch <= 1'b0;
    end else begin
      if (valid_i) begin
        if (wnext[CSB:0] == COUNT[CSB:0]) begin
          // Count-limit reached, switch bank
          waddr  <= {wbank, {CBITS{1'b0}}};
          switch <= 1'b1;
        end else begin
          waddr  <= wnext;
          switch <= 1'b0;
        end
        isram[waddr] <= idata_i;
        qsram[waddr] <= qdata_i;
      end else begin
        switch <= 1'b0;
      end
    end
  end


  // -- Signal that each bank has been filled -- //

  reg start, fired, ended;

  always @(posedge vis_clk) begin
    if (!reset_n) begin
      start <= 1'b0;
      fired <= 1'b0;
      ended <= 1'b1;
    end else begin
      start <= switch & ~fired;
      fired <= switch;
      ended <= ~valid_i;
    end
  end


  // -- Read-back of antenna IQ signals, with "multistage ordering" -- //

  reg frame;
  reg [TSB:0] taddr;
  wire [TSB:0] tnext = taddr + 1;
  wire tlast = tnext == TRATE[TSB:0];
  reg tstep;

  reg valid, first, last;
  reg [MSB:0] idata, qdata;
  reg [CSB:0] raddr;
  wire [CSB:0] rnext = raddr + 1;
  wire rlast = rnext[CSB:0] == COUNT[CSB:0];
  reg [ASB:CBITS] rbank;

  assign valid_o = valid;
  assign first_o = first;
  assign last_o  = last;
  assign taddr_o = taddr;
  assign idata_o = idata;
  assign qdata_o = qdata;

  // Transaction framing unit
  always @(posedge vis_clk) begin
    if (!reset_n) begin
      taddr <= {TBITS{1'b0}};
      frame <= 1'b0;
      rbank <= {BBITS{1'b0}};
      tstep <= 1'b0;
    end else begin
      if (start) begin
        frame <= 1'b1;
      end else if (rlast && tlast && ended) begin
        frame <= 1'b0;
      end

      if (rlast && tlast) begin
        rbank <= rbank + 1;
      end

      tstep <= rlast;

      if (!frame && valid) begin
        taddr <= {TBITS{1'b0}};
        rbank <= {BBITS{1'b0}};
      end else if (tstep) begin
        if (tlast) begin
          taddr <= {TBITS{1'b0}};
        end else begin
          taddr <= tnext;
        end
      end
    end
  end

  // Read-address and read-data unit
  always @(posedge vis_clk) begin
    if (!reset_n) begin
      raddr <= {CBITS{1'b0}};
    end else begin
      idata <= isram[{rbank, raddr}];
      qdata <= qsram[{rbank, raddr}];

      if (frame) begin
        if (rlast) begin
          raddr <= {CBITS{1'b0}};
        end else begin
          raddr <= rnext;
        end
      end else begin
        raddr <= {CBITS{1'b0}};
      end
    end
  end

  always @(posedge vis_clk) begin
    if (!reset_n) begin
      valid <= 1'b0;
      first <= 1'b0;
      last  <= 1'b0;
    end else begin
      valid <= frame;
      first <= frame & (~valid | last);
      last  <= rlast & tlast;
    end
  end

endmodule  // sigbuffer
