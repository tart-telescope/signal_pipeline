`timescale 1ns / 100ps
module tart_correlator (
    sig_clock,
    vis_clock,
    bus_clock,
    reset_ni,
    enable_i,

    sig_idata_i,
    sig_qdata_i,
    sig_valid_i,
    sig_ready_o,
    sig_last_i,

    vis_start_o,
    vis_frame_o,

    bus_revis_o,
    bus_imvis_o,
    bus_valid_o,
    bus_ready_i,
    bus_last_o
);

  // FIXME: The `COUNT` parameter has to be the same as `CORES`, due to the way
  //   that results are pipelined? Explicitly, after summing `COUNT` values,
  //   this partial-sum is output onto the pipelined "MUX", to be sent to the
  //   accumulator FU?

  parameter integer WIDTH = 32;  // Number of antennas/signals
  parameter integer WBITS = 5;  // Log2(#width)

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
  parameter integer MUXBITS = 3;

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

  // Control and status signals
  output vis_start_o;
  output vis_frame_o;

  // AXI4-Stream input for the visibilities
  input [MSB:0] sig_idata_i;
  input [MSB:0] sig_qdata_i;
  input sig_valid_i;
  input sig_last_i;  // todo: not useful?
  output sig_ready_o;

  // AXI4-Stream output for the visibilities
  output [SSB:0] bus_revis_o;
  output [SSB:0] bus_imvis_o;
  input bus_ready_i;
  output bus_valid_o;
  output bus_last_o;


  /**
   *  Input-buffering SRAM's for signal IQ data.
   */
  wire vis_valid_w, vis_first_w, vis_last_w;
  wire [TSB:0] vis_taddr_w;
  wire [MSB:0] vis_idata_w, vis_qdata_w;

  sigbuffer #(
      .WIDTH(WIDTH),
      .TRATE(TRATE),
      .TBITS(TBITS),
      .COUNT(COUNT),
      .CBITS(CBITS),
      .BBITS(BBITS)
  ) SIGBUF0 (
      .sig_clk(sig_clock),
      .vis_clk(vis_clock),
      .reset_n(reset_ni),
      // Antenna/source signals
      .valid_i(sig_valid_i),
      .idata_i(sig_idata_i),
      .qdata_i(sig_qdata_i),
      // Delayed, up-rated, looped signals
      .valid_o(vis_valid_w),
      .first_o(vis_first_w),
      .last_o (vis_last_w),
      .taddr_o(vis_taddr_w),
      .idata_o(vis_idata_w),
      .qdata_o(vis_qdata_w)
  );


  /**
   *  Correlator array, with daisy-chained outputs.
   */
  reg vis_enable = 1'b0;

  always @(posedge vis_clock) begin
    if (!reset_ni) begin
      vis_enable <= 1'b0;
    end else begin
      vis_enable <= frame;
    end
  end

  wire [SSB:0] re_w[CORES+1];
  wire [SSB:0] im_w[CORES+1];

  wire [SSB:0] acc_re, acc_im;

  assign re_w[0] = {SUMBITS{1'bx}};
  assign im_w[0] = {SUMBITS{1'bx}};

  assign acc_re  = re_w[CORES];
  assign acc_im  = im_w[CORES];

  genvar ii;
  generate
    for (ii = 0; ii < CORES; ii = ii + 1) begin : gen_corr_inst
      correlator #(
          .WIDTH(WIDTH),
          .SBITS(WBITS),
          .COUNT(COUNT),
          .CBITS(ADDR),
          .XBITS(MUXBITS)
      ) CORR (
          // Inputs
          .clock_i (vis_clock),
          .reset_ni(reset_ni),
          .enable_i(vis_enable),

          .idata_i(idata),
          .qdata_i(qdata),

          .revis_i(re_w[ii]),
          .imvis_i(im_w[ii]),

          // Outputs
          .revis_o(re_w[ii+1]),
          .imvis_o(im_w[ii+1]),
          .valid_o(),
          .ready_i()
      );
    end  // gen_corr_inst
  endgenerate


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
  ) ACCUM0 (
      .clock_i (vis_clock),
      .reset_ni(reset_ni),
      .enable_i(acc_enable),

      // Inputs
      .revis_i(revis_i[SSB:0]),
      .imvis_i(imvis_i[SSB:0]),

      // Outputs
      .revis_o(revis_o[MSB:0]),
      .imvis_o(imvis_o[MSB:0]),
      .valid_o(valid_o),
      .ready_i(ready_i),
      .last_o (last_o)
  );


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

  assign bus_valid_o = b_vld;
  assign bus_last_o  = b_lst;
  assign bus_revis_o = revis;
  assign bus_imvis_o = imvis;

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
