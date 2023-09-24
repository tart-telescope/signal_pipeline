`timescale 1ns / 100ps
module toy_correlator (
    sig_clock,

    bus_clock,
    bus_rst_n,

    vis_clock,
    vis_rst_n,

    // Status signals
    vis_start_o,
    vis_frame_o,

    // AXI4 Stream of antenna data
    sig_valid_i,
    sig_last_i,
    sig_idata_i,
    sig_qdata_i,

    // AXI4 Stream of visibilities data
    bus_revis_o,
    bus_imvis_o,
    bus_valid_o,
    bus_ready_i,
    bus_last_o
);

  parameter integer WIDTH = 4;  // Number of antennas/signals
  localparam WBITS = $clog2(WIDTH);
  localparam MSB = WIDTH - 1;

  // Source-signal multiplexor parameters
  parameter integer MUX_N = 4;
  localparam integer XBITS = $clog2(MUX_N);
  localparam integer XSB = XBITS - 1;

  parameter integer CORES = 1;  // Number of correlator cores
  localparam integer UBITS = $clog2(CORES);  // Log2(#cores)
  localparam integer USB = UBITS - 1;

  // Time-multiplexing rate; i.e., clock multiplier
  parameter integer TRATE = 15;
  localparam integer TBITS = $clog2(TRATE);  // ceil(Log2(TRATE))
  localparam integer TSB = TBITS - 1;

  // Every 'COUNT' samples, compute partial-visibilities to accumumlate
  parameter integer LOOP0 = 3;
  localparam integer LBITS = $clog2(LOOP0);
  parameter integer LOOP1 = 5;
  localparam integer HBITS = $clog2(LOOP1);
  localparam integer COUNT = LOOP0 * LOOP1;  // Number of terms in partial sums
  localparam integer CBITS = $clog2(COUNT);  // Bit-width of loop-counter
  localparam integer CSB = CBITS - 1;

  parameter integer ACCUM = 32;  // Bit-width of accumulators
  localparam integer VSB = ACCUM - 1;

  parameter integer SBITS = 7;  // Bit-width of partial-sums
  localparam integer SSB = SBITS - 1;

  // Buffer SRAM parameters
  localparam integer BBITS = 1;  // Number of bits for the bank-number
  localparam integer WORDS = 1 << (BBITS + CBITS);  // Buffer SRAM size
  localparam integer BANKS = BBITS << 1;
  localparam integer BSB = BBITS - 1;


  input sig_clock;

  input bus_clock;
  input bus_rst_n;

  input vis_clock;
  input vis_rst_n;

  // Status signals
  output vis_start_o;
  output vis_frame_o;

  // AXI4 Stream of antenna data
  input sig_valid_i;
  input sig_last_i;
  input [MSB:0] sig_idata_i;
  input [MSB:0] sig_qdata_i;

  // AXI4 Stream of visibilities data
  output [VSB:0] bus_revis_o;
  output [VSB:0] bus_imvis_o;
  output bus_valid_o;
  output bus_ready_i;
  output bus_last_o;


  /**
   * Input-buffering SRAM's for (antenna) signal IQ data.
   *
   * Every 'COUNT' input samples a full set of (partially-summed) visibility
   * contributions are computed, and forwarded to the final-stage accumulators.
   * The following buffer stores two (or more) banks of these 'COUNT' samples,
   * and streams them (with the correct ordering) to the correlators, switching
   * banks at the end of each block (of 'COUNT' samples).
   */
  wire buf_valid_w, buf_first_w, buf_last_w;
  wire [TSB:0] buf_taddr_w;
  wire [MSB:0] buf_idata_w, buf_qdata_w;

  sigbuffer #(
      .WIDTH(WIDTH),
      .TRATE(TRATE),
      .COUNT(COUNT),
      .BBITS(BBITS)
  ) SIGBUF0 (
      .sig_clk(sig_clock),
      .vis_clk(vis_clock),
      .reset_n(vis_rst_n),
      // Antenna/source signals
      .valid_i(sig_valid_i),
      .idata_i(sig_idata_i),
      .qdata_i(sig_qdata_i),
      // Delayed, up-rated, looped signals
      .valid_o(buf_valid_w),
      .first_o(buf_first_w),
      .last_o (buf_last_w),
      .taddr_o(buf_taddr_w),
      .idata_o(buf_idata_w),
      .qdata_o(buf_qdata_w)
  );


  // -- Correlator control-signals -- //

  localparam integer LZERO = {LBITS{1'b0}};
  localparam integer HZERO = {HBITS{1'b0}};

  reg [LBITS-1:0] cntlo;
  wire [LBITS-1:0] lnext = cntlo + 1;
  wire lomax = lnext == LOOP0[LBITS-1:0];

  reg [HBITS-1:0] cnthi;
  wire [HBITS-1:0] hnext = cnthi + 1;
  wire himax = hnext == LOOP1[HBITS-1:0];

  wire cnext = lomax | buf_first_w;  // todo: make synchronous ...

  always @(posedge vis_clock) begin
    if (!vis_rst_n) begin
      cntlo <= LZERO;
      cnthi <= HZERO;
    end else if (buf_valid_w) begin
      if (lomax) begin
        cntlo <= LZERO;
        if (himax) begin
          cnthi <= HZERO;
        end else begin
          cnthi <= hnext;
        end
      end else begin
        cntlo <= lnext;
      end
    end
  end


  /**
   *  Correlator array, with daisy-chained outputs.
   */
  wire [SSB:0] re_w[CORES+1];
  wire [SSB:0] im_w[CORES+1];

  wire [SSB:0] acc_re, acc_im;
  wire [CORES:0] vlds;

  assign re_w[0] = {SBITS{1'bx}};
  assign im_w[0] = {SBITS{1'bx}};

  assign acc_re  = re_w[CORES];
  assign acc_im  = im_w[CORES];


  // -- Antenna signal source-select -- //

localparam [7:0] ATAPS = {2'b00, 2'b01, 2'b10, 2'b11};
localparam [7:0] BTAPS = {2'b00, 2'b01, 2'b10, 2'b11};

localparam [29:0] ASELS = {2'b00, 2'b00, 2'b00, 2'b00,
                           2'b01, 2'b01, 2'b01, 2'b01,
                           2'b10, 2'b10, 2'b10, 2'b10,
                           2'b11, 2'b11, 2'b11};
localparam [29:0] BSELS = {2'b00, 2'b01, 2'b10, 2'b11,
                           2'b00, 2'b01, 2'b10, 2'b11,
                           2'b00, 2'b01, 2'b10, 2'b11,
                           2'b00, 2'b01, 2'b10};

  wire mux_valid;
  wire mux_ai, mux_aq, mux_bi, mux_bq;

  sigsource #(
      .WIDTH(WIDTH),
      .MUX_N(MUX_N),
      .TRATE(TRATE),
      .ATAPS(ATAPS),
      .BTAPS(BTAPS),
      .ASELS(ASELS),
      .BSELS(BSELS)
  ) SIGSRC0 (
      .clock(vis_clock),
      .reset_n(vis_rst_n),
      // Inputs
      .valid_i(buf_valid_w),
      .first_i(buf_first_w),
      .last_i(buf_last_w),
      .taddr_i(buf_taddr_w),
      .idata_i(buf_idata_w),
      .qdata_i(buf_qdata_w),
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

  localparam ABITS = 1 << LBITS;

  wire auto = 1'b0;  // todo: ...
  wire cor_valid;
  wire [VSB:0] cor_revis, cor_imvis;

  correlate #(
      .WIDTH(ABITS)
  ) CORRELATE0 (
      .clock(vis_clock),
      .reset_n(vis_rst_n),
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
  reg [VSB:0] revis, imvis;

  assign valid_o = succs;
  assign first_o = 1'bx;  // todo: ...
  assign last_o  = 1'bx;  // todo: ...
  assign revis_o = revis;
  assign imvis_o = imvis;

  always @(posedge clock) begin
    if (!vis_rst_n) begin
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


  /**
   *  Accumulates each of the partial-sums into the full-width visibilities.
   */
  wire vis_first = 1'b0;  // todo: ...
  wire vis_last = 1'b0;

  wire [ACCUM-1:0] acc_revis, acc_imvis;
  wire acc_valid, acc_last;

  accumulator #(
      .CORES(CORES),
      .TRATE(TRATE),
      .WIDTH(ACCUM),
      .SBITS(SBITS)
  ) ACCUM0 (
      .clock  (vis_clock),
      .reset_n(vis_rst_n),

      // Inputs
      .valid_i(vlds[CORES]),
      .first_i(vis_first),
      .last_i (vis_last),
      .revis_i(re_w[CORES]),
      .imvis_i(im_w[CORES]),

      // Outputs
      .valid_o(acc_valid),
      .last_o (acc_last),
      .revis_o(acc_revis),
      .imvis_o(acc_imvis)
  );


  /**
   *  Output SRAM's that store visibilities, while waiting to be sent to the
   *  host system.
   */

  wire acc_ready;
  wire [ACCUM+VSB:0] acc_tdata, bus_tdata;

  assign acc_tdata   = {acc_revis, acc_imvis};

  assign bus_revis_o = bus_tdata[ACCUM+VSB:ACCUM];
  assign bus_imvis_o = bus_tdata[VSB:0];

  axis_async_fifo #(
      .DEPTH(16),
      .DATA_WIDTH(WIDTH + WIDTH),
      .LAST_ENABLE(1),
      .ID_ENABLE(0),
      .DEST_ENABLE(0),
      .USER_ENABLE(0),
      .RAM_PIPELINE(1),
      .OUTPUT_FIFO_ENABLE(0),
      .FRAME_FIFO(1)
  ) axis_async_fifo_inst (
      .s_clk(vis_clock),
      .s_rst(~vis_rst_n),
      .s_axis_tdata(acc_tdata),
      .s_axis_tkeep('bx),
      .s_axis_tvalid(acc_valid),
      .s_axis_tready(acc_ready),
      .s_axis_tlast(acc_last),
      .s_axis_tid('bx),
      .s_axis_tdest('bx),
      .s_axis_tuser('bx),

      .m_clk(bus_clock),
      .m_rst(~bus_rst_n),
      .m_axis_tdata(bus_tdata),
      .m_axis_tkeep(),
      .m_axis_tvalid(bus_valid_o),
      .m_axis_tready(bus_ready_i),
      .m_axis_tlast(bus_last_o),
      .m_axis_tid(),
      .m_axis_tdest(),
      .m_axis_tuser(),

      .s_pause_req(1'b0),
      .s_pause_ack(),
      .m_pause_req(1'b0),
      .m_pause_ack(),

      .s_status_depth(),
      .s_status_depth_commit(),
      .s_status_overflow(),
      .s_status_bad_frame(),
      .s_status_good_frame(),

      .m_status_depth(),
      .m_status_depth_commit(),
      .m_status_overflow(),
      .m_status_bad_frame(),
      .m_status_good_frame()
  );


  // -- Simulation sanitisers -- //

  always @(posedge vis_clock) begin
    if (vis_rst_n) begin
      if (!acc_ready && acc_valid) begin
        $error("Oh noes, the FIFO has overflowed!");
      end
    end
  end


endmodule  // toy_correlator
