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
  localparam integer PBITS = SUMBITS - 2;
  localparam integer PSUMS = (1 << PBITS) - 1;

  localparam integer MSB = WIDTH - 1;
  localparam integer ASB = ACCUM - 1;


  /**
   *  System-wide signals.
   */
  reg reset_n = 1'b0;
  reg enable = 1'b0;
  reg sig_clock = 1'b1;
  reg vis_clock = 1'b1;
  reg bus_clock = 1'b1;

  always #150 sig_clock <= ~sig_clock;
  always #5 vis_clock <= ~vis_clock;
  always #10 bus_clock <= ~bus_clock;

  initial begin : SIM_INIT
    #305 reset_n <= 1'b1;

    #300 enable <= 1'b1;
    while (!bus_last) #300 valid <= 1'b1;

    #6000 $finish;
  end


  /**
   *  Source signal data generation and streaming.
   */
  localparam integer SAMPLES = 1024;
  localparam integer SAMPLEBITS = 10;

  reg [MSB:0] isamples[SAMPLES];
  reg [MSB:0] qsamples[SAMPLES];

  integer ii;
  initial begin : SIM_DATA
    for (ii = 0; ii < SAMPLES; ii = ii + 1) begin
      isamples[ii] = $urandom;
      qsamples[ii] = $urandom;
    end
  end  // SIM_DATA

  reg  [SAMPLEBITS-1:0] saddr = {SAMPLEBITS{1'b0}};
  wire [SAMPLEBITS-1:0] snext = saddr + 1;

  always @(posedge sig_clock) begin
    if (!reset_n) begin
      saddr <= {SAMPLEBITS{1'b0}};
    end else begin
      if (valid && sig_ready) begin
        saddr <= snext;
      end
    end
  end


  reg  sig_valid = 1'b0;
  reg  sig_last = 1'b0;
  wire sig_ready;
  wire [ASB:0] sig_idata, sig_qdata;

  wire start_w, frame_w;

  wire [ASB:0] bus_revis, bus_imvis;
  wire bus_valid, bus_last;
  reg bus_ready = 1'b0;

  always @(posedge bus_clock) begin
    if (!reset_n) begin
      bus_ready <= 1'b0;
    end else begin
      if (enable) begin
        bus_ready <= 1'b1;
      end else if (bus_valid && bus_ready && bus_last) begin
        bus_ready <= 1'b0;
      end
    end
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
  ) CORRELATOR0 (
      .sig_clock(sig_clock),
      .vis_clock(vis_clock),
      .bus_clock(bus_clock),
      .reset_ni (reset_n),
      .enable_i (enable),

      // Control and status signals
      .vis_start_o(start_w),
      .vis_frame_o(frame_w),

      // Antenna source signals
      .sig_idata_i(sig_idata),
      .sig_qdata_i(sig_qdata),
      .sig_valid_i(sig_valid),
      .sig_ready_o(sig_ready),
      .sig_last_i (sig_last),

      // AXI4-Stream for the visibilities to the system bus
      .bus_revis_o(bus_revis),
      .bus_imvis_o(bus_imvis),
      .bus_valid_o(bus_valid),
      .bus_ready_i(bus_ready),
      .bus_last_o (bus_last)
  );

endmodule  // top_tb
