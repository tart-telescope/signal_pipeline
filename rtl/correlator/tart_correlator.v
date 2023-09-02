`timescale 1ns / 100ps
module tart_correlator (  /*AUTOARG*/);

  // FIXME: The `COUNT` parameter has to be the same as `CORES`, due to the way
  //   that results are pipelined? Explicitly, after summing `COUNT` values,
  //   this partial-sum is output onto the pipelined "MUX", to be sent to the
  //   accumulator FU?

  parameter integer WIDTH = 32;  // Number of antennas/signals
  parameter integer CORES = 18;  // Number of correlator cores
  parameter integer CBITS = 5;  // Log2(#cores)
  parameter integer ACCUM = 36;  // Bit-width of accumulators

  parameter integer BBITS = 1;  // Number of bits for the bank-number
  parameter integer WORDS = 32;  // Buffer SRAM size
  parameter integer COUNT = 15;  // Number of terms for partial sums

  // Time-multiplexing rate; i.e., clock multiplier
  parameter integer TRATE = 30;
  parameter integer TBITS = 5;  // ceil(Log2(TRATE))

  parameter integer ADDR = 4;
  parameter integer SUMBITS = 6;

  localparam integer BANKS = BBITS << 1;
  localparam integer BSB = BBITS - 1;
  localparam integer CSB = CBITS - 1;
  localparam integer MSB = WIDTH - 1;
  localparam integer TSB = TBITS - 1;
  localparam integer ASB = ADDR - 1;
  localparam integer SSB = SUMBITS - 1;

  input sig_clock;  // note: the clock from the radio RX ADC's
  input vis_clock;  // note: must be (integer multiple) sync to 'sig_clock'
  input bus_clock;  // note: typically ascynchronous, relative to the above

  input reset_ni;
  input enable_i;

  input [MSB:0] idata_i;
  input [MSB:0] qdata_i;

  output start_o;
  output frame_o;

  // AXI4-Stream output for the visibilities
  output [SSB:0] revis_o;
  output [SSB:0] imvis_o;
  input ready_i;
  output valid_o;
  output last_o;


  /**
   *  Input-buffering SRAM's for signal IQ data.
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

  wire [ACCUM-1:0] revis_x, imvis_x;
  wire x_vld, x_lst;

  accumulator #(
      .WIDTH(ACCUM),
      .TOTAL(TOTAL)
  ) ACCUM0 (  /*AUTOINST*/);


  /**
   *  Output SRAM's that store visibilities, while waiting to be sent to the
   *  host system.
   */
  localparam integer OSIZE = BANKS * TOTAL;
  localparam integer OBITS = CBITS + TBITS;
  localparam integer OSB = OBITS - 1;

  // -- Write port -- //
  reg [ACCUM-1:0] reram[OSIZE];
  reg [ACCUM-1:0] imram[OSIZE];
  reg [OSB:0] oaddr = {OBITS{1'b0}};
  wire [OSB:0] onext = oaddr + 1;
  reg [BSB:0] obank = {BBITS{1'b0}};
  reg x_rdy = 1'b0;

  always @(posedge vis_clock) begin
    if (!reset_ni) begin
      x_rdy <= 1'b0;
      oaddr <= {OBITS{1'b0}};
      obank <= {BBITS{1'b0}};
    end else begin
      // todo: handle case when all banks full?

      if (x_vld) begin
        // todo: there are some edge-cases to handle, when 'onext == 0'?
        if (onext == TOTAL) begin
          oaddr <= {OBITS{1'b0}};
          obank <= obank + 1;
        end else begin
          oaddr <= onext;
        end

        // todo:
        reram[{obank, oaddr}] <= revis_x;
        imram[{obank, oaddr}] <= imvis_x;
      end
    end
  end

  // todo: cross-domain signals for indicating that data is ready ...

  // -- AXI4-Stream Read Port -- //
  reg [ACCUM-1:0] revis;
  reg [ACCUM-1:0] imvis;
  reg [OSB:0] baddr = {OBITS{1'b0}};
  wire [OSB:0] bnext = baddr + 1;
  reg [BSB:0] bbank = {BBITS{1'b0}};
  reg b_vld = 1'b0;
  reg b_lst = 1'b0;

  assign valid_o = b_vld;
  assign last_o  = b_lst;
  assign revis_o = revis;
  assign imvis_o = imvis;

  always @(posedge bus_clock) begin
    if (!reset_ni) begin
      baddr <= {OBITS{1'b0}};
      bbank <= {BBITS{1'b0}};
      b_vld <= 1'b0;
      b_lst <= 1'b0;
    end else begin
      // todo: 'b_vld' logic

      if (b_vld && ready_i) begin
        if (bnext == TOTAL) begin
          baddr <= {OBITS{1'b0}};
          bbank <= bbank + 1;
        end else begin
          baddr <= bnext;
        end

        // todo: correct?
        if (bnext == TOTAL - 1) begin
          b_lst <= 1'b1;
        end else begin
          b_lst <= 1'b0;
        end

        revis <= reram[{bbank, baddr}];
        imvis <= imram[{bbank, baddr}];
      end
    end
  end

endmodule  // tart_correlator
