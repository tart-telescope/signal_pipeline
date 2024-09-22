`timescale 1ns / 100ps
module top_tb;

  reg clk16 = 1'b1, clk25 = 1'b1;
  reg arst_n;

  always #30 clk16 <= ~clk16;
  always #20 clk25 <= ~clk25;

  initial begin
    #10 arst_n <= 1'b0;
    #60 arst_n <= 1'b1;
  end

  // -- Simulation Data -- //

  initial begin
    // #659000 $dumpfile("top_tb.vcd");
    $dumpfile("top_tb.vcd");
    $dumpvars;
  end

  // initial #670000 $finish;

  initial begin
    #3800000 $finish;
  end

  // -- Simulation Signals -- //

  wire SCLK, MISO, MOSI, CS_N;
  wire usb_clock, usb_rst_n, ulpi_dir, ulpi_nxt, ulpi_stp;
  wire [7:0] ulpi_data;

  wire ddr_rst_n, ddr_ck_p, ddr_ck_n, ddr_cke, ddr_cs_n;
  wire ddr_ras_n, ddr_cas_n, ddr_we_n, ddr_odt;
  wire [15:0] ddr_dq;
  wire [1:0] ddr_dqs_p, ddr_dqs_n, ddr_dm;
  wire [ 2:0] ddr_ba;
  wire [12:0] ddr_a;


  //
  //  Simulation Stimulus
  ///

  /**
   * Wrapper to the VPI model of a USB host, for providing the stimulus.
   */
  ulpi_shell U_ULPI_HOST1 (
      .clock(usb_clock),
      .rst_n(usb_rst_n),
      .dir  (ulpi_dir),
      .nxt  (ulpi_nxt),
      .stp  (ulpi_stp),
      .data (ulpi_data)
  );

  // -- DDR3 Simulation Model from Micron -- //

  ddr3 ddr3_sdram_inst (
      .rst_n(ddr_rst_n),
      .ck(ddr_ck_p),
      .ck_n(ddr_ck_n),
      .cke(ddr_cke),
      .cs_n(ddr_cs_n),
      .ras_n(ddr_ras_n),
      .cas_n(ddr_cas_n),
      .we_n(ddr_we_n),
      .dm_tdqs(ddr_dm),
      .ba(ddr_ba),
      .addr({1'b0, ddr_a}),
      .dq(ddr_dq),
      .dqs(ddr_dqs_p),
      .dqs_n(ddr_dqs_n),
      .tdqs_n(),
      .odt(ddr_odt)
  );


  //
  //  Core Under New Tests
  ///

  top #(
      .ANTENNAS (4),
      .AXI_WIDTH(8)
  ) U_TOP1 (
      .CLK_16(clk16),
      .clk_26(clk25),
      .rst_n(arst_n),
      .SCLK(SCLK),
      .MISO(MISO),
      .MOSI(MOSI),
      .CS(CS_N),

      .ulpi_clk (usb_clock),
      .ulpi_rst (usb_rst_n),
      .ulpi_dir (ulpi_dir),
      .ulpi_nxt (ulpi_nxt),
      .ulpi_stp (ulpi_stp),
      .ulpi_data(ulpi_data),

      .ddr_ck(ddr_ck_p),
      .ddr_ck_n(ddr_ck_n),
      .ddr_cke(ddr_cke),
      .ddr_rst_n(ddr_rst_n),
      .ddr_cs(ddr_cs_n),
      .ddr_ras(ddr_ras_n),
      .ddr_cas(ddr_cas_n),
      .ddr_we(ddr_we_n),
      .ddr_odt(ddr_odt),
      .ddr_bank(ddr_ba),
      .ddr_addr(ddr_a),
      .ddr_dm(ddr_dm),
      .ddr_dqs(ddr_dqs_p),
      .ddr_dqs_n(ddr_dqs_n),
      .ddr_dq(ddr_dq)
  );


endmodule  /* top_tb */
