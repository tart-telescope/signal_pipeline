`timescale 1ns / 100ps
/**
 * DDR3 controller with both a simple AXI-Stream interface, for requests from
 * the SPI/USB core, as well as an AXI4 write port (address, data, and response
 * channels), for raw data from the radio ADCs.
 *
 * Copyright 2024, Patrick Suggate.
 *
 */
// Comment this out to speed up Icarus Verilog simulations
`define __gowin_for_the_win

`ifndef __icarus
// Slower simulation performance, as the IOB's have to be simulated
`define __gowin_for_the_win
`endif  /* !__icarus */

module tart_ddr3 #(
    parameter SRAM_BYTES = 2048,
    parameter DFIFO_BYPASS = 0,
    parameter DATA_WIDTH = 32,
    localparam MSB = DATA_WIDTH - 1,
    parameter DATA_KEEPS = DATA_WIDTH / 8,
    localparam SSB = DATA_KEEPS - 1,
    parameter ADDR_WIDTH = 27,
    localparam ASB = ADDR_WIDTH - 1,
    parameter ID_WIDTH = 4,
    localparam ISB = ID_WIDTH - 1,

    // Default clock-setup for 125 MHz DDR3 clock, from 27 MHz source
    parameter CLK_IN_FREQ = "27",
    parameter CLK_IDIV_SEL = 3,  // in  / 4
    parameter CLK_FBDV_SEL = 36,  //     x37
    parameter CLK_ODIV_SEL = 4,  // out / 4 (x2 DDR3 clock)
    parameter CLK_SDIV_SEL = 2,  //     / 2
    parameter DDR_FREQ_MHZ = 125,  // out: 249.75 / 2 MHz

    // Settings for DLL=off mode
    parameter DDR_CL = 6,
    parameter DDR_CWL = 6,
    parameter PHY_WR_DELAY = 3,
    parameter PHY_RD_DELAY = 3,

    // Data-path widths
    localparam DDR_DQ_WIDTH = 16,
    localparam DSB = DDR_DQ_WIDTH - 1,

    localparam DDR_DM_WIDTH = 2,
    localparam QSB = DDR_DM_WIDTH - 1,

    // Address widths
    localparam DDR_ROW_BITS = 13,
    localparam RSB = DDR_ROW_BITS - 1,

    localparam DDR_COL_BITS = 10,
    localparam CSB = DDR_COL_BITS - 1,

    // Trims an additional clock-cycle of latency, if '1'
    parameter LOW_LATENCY = 1'b0,  // 0 or 1
    parameter WR_PREFETCH = 1'b0,  // 0 or 1
    parameter RD_FASTPATH = 1'b0,  // 0 or 1
    parameter INVERT_MCLK = 0,  // Todo: unfinished, and to allow extra shifts
    parameter INVERT_DCLK = 0,  // Todo: unfinished, and to allow extra shifts
    parameter WRITE_DELAY = 2'b00,
    parameter CLOCK_SHIFT = 2'b10
) (
    input osc_in,  // Default: 27.0 MHz
    input arst_n,  // 'S1' button for async-reset

    input bus_clock,  // Default: 60.0 MHz
    input bus_reset,

    output ddr3_conf_o,
    output ddr_reset_o,  // Default: 245.52 MHz
    output ddr_clock_o,  // Default: 122.76 MHz
    output ddr_clkx2_o,

    // From USB or SPI
    input s_tvalid,
    output s_tready,
    input s_tkeep,
    input s_tlast,
    input [7:0] s_tdata,

    // To USB or SPI
    output m_tvalid,
    input m_tready,
    output m_tkeep,
    output m_tlast,
    output [7:0] m_tdata,

    // Raw-data Write Port (default: 122.76 MHz, DDR/AXI domain)
    input axi_awvalid_i,  // AXI4 Write Address Channel
    output axi_awready_o,
    input [1:0] axi_awburst_i,
    input [7:0] axi_awlen_i,
    input [ISB:0] axi_awid_i,
    input [ASB:0] axi_awaddr_i,
    input axi_wvalid_i,  // AXI4 Write Data Channel
    output axi_wready_o,
    input axi_wlast_i,
    input [SSB:0] axi_wstrb_i,
    input [MSB:0] axi_wdata_i,
    output axi_bvalid_o,  // AXI4 Write Response Channel
    input axi_bready_i,
    output [1:0] axi_bresp_o,
    output [ISB:0] axi_bid_o,

    // 1Gb DDR3 SDRAM pins
    output ddr_ck,
    output ddr_ck_n,
    output ddr_cke,
    output ddr_rst_n,
    output ddr_cs,
    output ddr_ras,
    output ddr_cas,
    output ddr_we,
    output ddr_odt,
    output [2:0] ddr_bank,
    output [RSB:0] ddr_addr,
    output [QSB:0] ddr_dm,
    inout [QSB:0] ddr_dqs,
    inout [QSB:0] ddr_dqs_n,
    inout [DSB:0] ddr_dq
);

  // -- Constants -- //

  // Note: (AXI4) byte address, not burst-aligned address
  localparam ADDRS = DDR_COL_BITS + DDR_ROW_BITS + 4;

  initial begin
    if (ADDRS != ADDR_WIDTH) begin
      $error("DDR3 memory-address width (%d) does not match AXI width (%d)", ADDRS, ADDR_WIDTH);
      $fatal;
    end
    if (DATA_WIDTH != 2 * DDR_DQ_WIDTH) begin
      $error("DDR3 data-bus width (%d) not compatible with AXI width (%d)", DDR_DQ_WIDTH,
             DATA_WIDTH);
      $fatal;
    end
  end

  // -- DDR3 Core and AXI Interconnect Signals -- //

  // AXI4 Signals between Acquisition Unit and Memory Controller
  wire acq_awvalid, acq_awready, acq_wvalid, acq_wready, acq_wlast;
  wire acq_bvalid, acq_bready;
  wire [1:0] acq_awburst, acq_bresp;
  wire [7:0] acq_awlen;
  wire [ISB:0] acq_awid, acq_bid;
  wire [SSB:0] acq_wstrb;
  wire [MSB:0] acq_wdata;

  // DFI <-> PHY
  wire dfi_rst_n, dfi_cke, dfi_cs_n, dfi_ras_n, dfi_cas_n, dfi_we_n;
  wire dfi_odt, dfi_wstb, dfi_wren, dfi_rden, dfi_valid, dfi_last;
  wire [  2:0] dfi_bank;
  wire [RSB:0] dfi_addr;
  wire [SSB:0] dfi_mask;
  wire [MSB:0] dfi_wdata, dfi_rdata;

  wire dfi_calib, dfi_align;
  wire [2:0] dfi_shift;

  wire clk_x2, clk_x1, locked;
  wire clock, reset;

  // -- Signal Input & Output Assignments -- //

  assign acq_awvalid = axi_awvalid_i;
  assign axi_awready_o = acq_awready;
  assign acq_awburst = axi_awburst_i;
  assign acq_awlen = axi_awlen_i;
  assign acq_awid = axi_awid_i;
  assign acq_awaddr = axi_awaddr_i;

  assign acq_wvalid = axi_wvalid_i;
  assign axi_wready_o = acq_wready;
  assign acq_wlast = axi_wlast_i;
  assign acq_wstrb = axi_wstrb_i;
  assign acq_wdata = axi_wdata_i;

  assign axi_bvalid_o = acq_bvalid;
  assign acq_bready = axi_bready_i;
  assign axi_bid_o = acq_bid;
  assign axi_bresp_o = acq_bresp;

  // TODO: set up this clock, as the DDR3 timings are quite fussy ...

`ifdef __icarus
  //
  //  Simulation-Only Clocks & Resets
  ///
  reg dclk = 1, mclk = 0, lock_q = 0;

  localparam HCLK_DELAY = DDR_FREQ_MHZ > 100 ? 4.0 : 5.0;
  localparam QCLK_DELAY = DDR_FREQ_MHZ > 100 ? 2.0 : 2.5;

  assign clk_x2 = dclk;
  assign clk_x1 = mclk;
  assign locked = lock_q;

  always #QCLK_DELAY dclk <= ~dclk;
  always #HCLK_DELAY mclk <= ~mclk;
  initial #20 lock_q = 0;

  always @(posedge mclk or negedge arst_n) begin
    if (!arst_n) begin
      lock_q <= 1'b0;
    end else begin
      lock_q <= #100000 1'b1;
    end
  end

`else  /* !__icarus */

  // So 27.0 MHz divided by 4, then x29 = 195.75 MHz.
  gw2a_rpll #(
      .FCLKIN(CLK_IN_FREQ),
      .IDIV_SEL(CLK_IDIV_SEL),
      .FBDIV_SEL(CLK_FBDV_SEL),
      .ODIV_SEL(CLK_ODIV_SEL),
      .DYN_SDIV_SEL(CLK_SDIV_SEL)
  ) U_rPLL1 (
      .clkout(clk_x2),  // Default: 249.75  MHz
      .clockd(clk_x1),  // Default: 124.875 MHz
      .lock  (locked),
      .clkin (osc_in),
      .reset (~arst_n)
  );

`endif  /* !__icarus */

  assign ddr_reset_o = ~locked;
  assign ddr_clock_o = clk_x1;
  assign ddr_clkx2_o = clk_x2;

  // Internal clock assigments
  assign clock = clk_x1;
  assign reset = ~locked;

  // -- Processes & Dispatches Memory Requests -- //

  // AXI4 Signals between USB and the Memory Controller //
  wire usb_awvalid, usb_awready, usb_wvalid, usb_wready, usb_wlast;
  wire usb_bvalid, usb_bready;
  wire usb_arvalid, usb_arready, usb_rvalid, usb_rready, usb_rlast;
  wire [1:0] usb_awburst, usb_bresp, usb_arburst, usb_rresp;
  wire [7:0] usb_awlen, usb_arlen;
  wire [ISB:0] usb_awid, usb_bid, usb_arid, usb_rid;
  wire [SSB:0] usb_wstrb;
  wire [MSB:0] usb_wdata, usb_rdata;

  memreq #(
      .FIFO_DEPTH(SRAM_BYTES * 8 / DATA_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .STROBES(DATA_KEEPS),
      .WR_FRAME_FIFO(1)
  ) U_MEMREQ1 (
      .mem_clock(clock),  // DDR3 controller domain
      .mem_reset(reset),

      .bus_clock(bus_clock),  // SPI or USB domain
      .bus_reset(bus_reset),

      // From USB or SPI
      .s_tvalid(s_tvalid),
      .s_tready(s_tready),
      .s_tkeep (s_tkeep),
      .s_tlast (s_tlast),
      .s_tdata (s_tdata),

      // To USB or SPI
      .m_tvalid(m_tvalid),
      .m_tready(m_tready),
      .m_tkeep (m_tkeep),
      .m_tlast (m_tlast),
      .m_tdata (m_tdata),

      // Write -address(), -data(), & -response ports(), to/from DDR3 controller
      .awvalid_o(usb_awvalid),
      .awready_i(usb_awready),
      .awaddr_o(usb_awaddr),
      .awid_o(usb_awid),
      .awlen_o(usb_awlen),
      .awburst_o(usb_awburst),

      .wvalid_o(usb_wvalid),
      .wready_i(usb_wready),
      .wlast_o (usb_wlast),
      .wstrb_o (usb_wstrb),
      .wdata_o (usb_wdata),

      .bvalid_i(usb_bvalid),
      .bready_o(usb_bready),
      .bresp_i(usb_bresp),
      .bid_i(usb_bid),

      // Read -address & -data ports(), to/from the DDR3 controller
      .arvalid_o(usb_arvalid),
      .arready_i(usb_arready),
      .araddr_o(usb_araddr),
      .arid_o(usb_arid),
      .arlen_o(usb_arlen),
      .arburst_o(usb_arburst),

      .rvalid_i(usb_rvalid),
      .rready_o(usb_rready),
      .rlast_i(usb_rlast),
      .rresp_i(usb_rresp),
      .rid_i(usb_rid),
      .rdata_i(usb_rdata)
  );

  // -- Write-MUX for 2x AXI Write Channels -- //

  // AXI4 MUX-Output Signals for Memory Writes //
  wire mux_awvalid, mux_awready, mux_wvalid, mux_wready, mux_wlast;
  wire mux_bvalid, mux_bready;
  wire [1:0] mux_awburst, mux_bresp;
  wire [7:0] mux_awlen;
  wire [ISB:0] mux_awid, mux_bid;
  wire [SSB:0] mux_wstrb;
  wire [MSB:0] mux_wdata;

  axi_crossbar_wr #(
      .S_COUNT(2),
      .M_COUNT(1),
      .DATA_WIDTH(DATA_WIDTH),  // Default: 32b -> DDR3
      .ADDR_WIDTH(ADDR_WIDTH),
      .STRB_WIDTH(DATA_KEEPS),
      .S_ID_WIDTH(ID_WIDTH),
      .M_ID_WIDTH(ID_WIDTH),
      .AWUSER_ENABLE(0),
      .AWUSER_WIDTH(1),
      .WUSER_ENABLE(0),
      .WUSER_WIDTH(1),
      .BUSER_ENABLE(0),
      .BUSER_WIDTH(1),
      .S_THREADS({32'd1, 32'd1}),
      .S_ACCEPT({32'd1, 32'd1}),
      .M_REGIONS(1),
      .M_BASE_ADDR(0),
      .M_ADDR_WIDTH(ADDR_WIDTH),
      .M_CONNECT({{1'b1, 1'b1}}),
      .M_ISSUE({32'd1}),
      .M_SECURE({1'b0}),
      .S_AW_REG_TYPE({2'd1, 2'd1}),  // Plain registers
      .S_W_REG_TYPE({2'd2, 2'd2}),  // Skid buffers
      .S_B_REG_TYPE({2'd1, 2'd1})  // Plain registers
  ) U_XBAR1 (
      .clk(clock),
      .rst(reset),

      // AXI slave interfaces //
      .s_axi_awvalid({acq_awvalid, usb_awvalid}),
      .s_axi_awready({acq_awready, usb_awready}),
      .s_axi_awsize({3'd2, 3'd2}),
      .s_axi_awburst({acq_awburst, usb_awburst}),
      .s_axi_awlen({acq_awlen, usb_awlen}),
      .s_axi_awid   ({acq_awid, usb_awid}),
      .s_axi_awaddr({acq_awaddr, usb_awaddr}),
      .s_axi_awlock({1'b0, 1'b0}),
      .s_axi_awcache({4'd3, 4'd3}),
      .s_axi_awprot({3'd2, 3'd2}),
      .s_axi_awqos({4'd0, 4'd0}),
      .s_axi_awuser({1'b0, 1'b0}),
      .s_axi_wvalid({acq_wvalid, usb_wvalid}),
      .s_axi_wready({acq_wready, usb_wready}),
      .s_axi_wlast({acq_wlast, usb_wlast}),
      .s_axi_wuser({1'b0, 1'b0}),
      .s_axi_wstrb({acq_wstrb, usb_wstrb}),
      .s_axi_wdata({acq_wdata, usb_wdata}),
      .s_axi_bvalid({acq_bvalid, usb_bvalid}),
      .s_axi_bready({acq_bready, usb_bvalid}),
      .s_axi_buser(),
      .s_axi_bid({acq_bid, usb_bid}),
      .s_axi_bresp({acq_bresp, usb_bresp}),

      // AXI master interfaces //
      .m_axi_awvalid(mux_awvalid),
      .m_axi_awready(mux_awready),
      .m_axi_awsize(),
      .m_axi_awburst(mux_awburst),
      .m_axi_awlen(mux_awlen),
      .m_axi_awid(mux_awid),
      .m_axi_awaddr(mux_awaddr),
      .m_axi_awlock(),
      .m_axi_awcache(),
      .m_axi_awprot(),
      .m_axi_awqos(),
      .m_axi_awregion(),
      .m_axi_awuser(),
      .m_axi_wvalid(mux_wvalid),
      .m_axi_wready(mux_wready),
      .m_axi_wlast(mux_wlast),
      .m_axi_wuser(),
      .m_axi_wstrb(mux_wstrb),
      .m_axi_wdata(mux_wdata),
      .m_axi_bvalid(mux_bvalid),
      .m_axi_bready(mux_bready),
      .m_axi_bid(mux_bid),
      .m_axi_bresp(mux_bresp),
      .m_axi_buser()
  );


  //
  //  DDR Core Under New Test
  ///

  axi_ddr3_lite #(
      .DDR_FREQ_MHZ(DDR_FREQ_MHZ),
      .DDR_ROW_BITS(DDR_ROW_BITS),
      .DDR_COL_BITS(DDR_COL_BITS),
      .DDR_DQ_WIDTH(DDR_DQ_WIDTH),
      .PHY_WR_DELAY(PHY_WR_DELAY),
      .PHY_RD_DELAY(PHY_RD_DELAY),
      .WR_PREFETCH (WR_PREFETCH),
      .LOW_LATENCY (LOW_LATENCY),
      .AXI_ID_WIDTH(ID_WIDTH),
      .MEM_ID_WIDTH(ID_WIDTH),
      .DFIFO_BYPASS(DFIFO_BYPASS),
      .PACKET_FIFOS(0)
  ) U_LITE (
      .arst_n(arst_n),  // Global, asynchronous reset

      .clock(clock),  // Memory clock (default: 122.76 MHz)
      .reset(reset),  // Synchronous reset

      .configured_o(ddr3_conf_o),

      // Write Port: {ACQ, USB} -> DDR3 //
      .axi_awvalid_i(mux_awvalid),
      .axi_awready_o(mux_awready),
      .axi_awaddr_i(mux_awaddr),
      .axi_awid_i(mux_awid),
      .axi_awlen_i(mux_awlen),
      .axi_awburst_i(mux_awburst),

      .axi_wvalid_i(mux_wvalid),
      .axi_wready_o(mux_wready),
      .axi_wlast_i (mux_wlast),
      .axi_wstrb_i (mux_wstrb),
      .axi_wdata_i (mux_wdata),

      .axi_bvalid_o(mux_bvalid),
      .axi_bready_i(mux_bready),
      .axi_bresp_o(mux_bresp),
      .axi_bid_o(mux_bid),

      // Read Port: DDR3 -> USB //
      .axi_arvalid_i(usb_arvalid),
      .axi_arready_o(usb_arready),
      .axi_araddr_i(usb_araddr),
      .axi_arid_i(usb_arid),
      .axi_arlen_i(usb_arlen),
      .axi_arburst_i(usb_arburst),

      .axi_rvalid_o(usb_rvalid),
      .axi_rready_i(usb_rready),
      .axi_rlast_o(usb_rlast),
      .axi_rresp_o(usb_rresp),
      .axi_rid_o(usb_rid),
      .axi_rdata_o(usb_rdata),

      // Connection to/from the DDR3 PHY //
      .dfi_align_o(dfi_align),
      .dfi_calib_i(dfi_calib),

      .dfi_rst_no(dfi_rst_n),
      .dfi_cke_o (dfi_cke),
      .dfi_cs_no (dfi_cs_n),
      .dfi_ras_no(dfi_ras_n),
      .dfi_cas_no(dfi_cas_n),
      .dfi_we_no (dfi_we_n),
      .dfi_odt_o (dfi_odt),
      .dfi_bank_o(dfi_bank),
      .dfi_addr_o(dfi_addr),

      .dfi_wstb_o(dfi_wstb),
      .dfi_wren_o(dfi_wren),
      .dfi_mask_o(dfi_mask),
      .dfi_data_o(dfi_wdata),

      .dfi_rden_o(dfi_rden),
      .dfi_rvld_i(dfi_valid),
      .dfi_last_i(dfi_last),
      .dfi_data_i(dfi_rdata)
  );


  // -- DDR3 PHY -- //

`ifdef __gowin_for_the_win

  // GoWin Global System Reset signal tree.
  GSR GSR (.GSRI(1'b1));

  gw2a_ddr3_phy #(
      .WR_PREFETCH(WR_PREFETCH),
      .DDR3_WIDTH (16),
      .ADDR_BITS  (DDR_ROW_BITS),
      .INVERT_MCLK(INVERT_MCLK),
      .INVERT_DCLK(INVERT_DCLK),
      .WRITE_DELAY(WRITE_DELAY),
      .CLOCK_SHIFT(CLOCK_SHIFT)
  ) U_PHY1 (
      .clock  (clock),
      .reset  (reset),
      .clk_ddr(clk_x2),

      .dfi_rst_ni(dfi_rst_n),
      .dfi_cke_i (dfi_cke),
      .dfi_cs_ni (dfi_cs_n),
      .dfi_ras_ni(dfi_ras_n),
      .dfi_cas_ni(dfi_cas_n),
      .dfi_we_ni (dfi_we_n),
      .dfi_odt_i (dfi_odt),
      .dfi_bank_i(dfi_bank),
      .dfi_addr_i(dfi_addr),

      .dfi_wstb_i(dfi_wstb),
      .dfi_wren_i(dfi_wren),
      .dfi_mask_i(dfi_mask),
      .dfi_data_i(dfi_wdata),

      .dfi_rden_i(dfi_rden),
      .dfi_rvld_o(dfi_valid),
      .dfi_last_o(dfi_last),
      .dfi_data_o(dfi_rdata),

      // For WRITE- & READ- CALIBRATION
      .dfi_align_i(dfi_align),
      .dfi_calib_o(dfi_calib),
      .dfi_shift_o(dfi_shift),  // In 1/4 clock-steps

      .ddr_ck_po(ddr_ck),
      .ddr_ck_no(ddr_ck_n),
      .ddr_rst_no(ddr_rst_n),
      .ddr_cke_o(ddr_cke),
      .ddr_cs_no(ddr_cs),
      .ddr_ras_no(ddr_ras),
      .ddr_cas_no(ddr_cas),
      .ddr_we_no(ddr_we),
      .ddr_odt_o(ddr_odt),
      .ddr_ba_o(ddr_bank),
      .ddr_a_o(ddr_addr),
      .ddr_dm_o(ddr_dm),
      .ddr_dqs_pio(ddr_dqs),
      .ddr_dqs_nio(ddr_dqs_n),
      .ddr_dq_io(ddr_dq)
  );

`else  /* !__gowin_for_the_win */

  // Generic PHY -- that probably won't synthesise correctly, due to how the
  // (read-)data is registered ...
  generic_ddr3_phy #(
      .DDR3_WIDTH(16),  // (default)
      .ADDR_BITS(DDR_ROW_BITS)  // default: 14
  ) U_PHY1 (
      .clock  (clock),
      .reset  (reset),
      .clk_ddr(clk_x2),

      .dfi_rst_ni(dfi_rst_n),
      .dfi_cke_i (dfi_cke),
      .dfi_cs_ni (dfi_cs_n),
      .dfi_ras_ni(dfi_ras_n),
      .dfi_cas_ni(dfi_cas_n),
      .dfi_we_ni (dfi_we_n),
      .dfi_odt_i (dfi_odt),
      .dfi_bank_i(dfi_bank),
      .dfi_addr_i(dfi_addr),

      .dfi_wstb_i(dfi_wstb),
      .dfi_wren_i(dfi_wren),
      .dfi_mask_i(dfi_mask),
      .dfi_data_i(dfi_wdata),

      .dfi_rden_i(dfi_rden),
      .dfi_rvld_o(dfi_valid),
      .dfi_last_o(dfi_last),
      .dfi_data_o(dfi_rdata),

      .ddr3_ck_po(ddr_ck),
      .ddr3_ck_no(ddr_ck_n),
      .ddr3_cke_o(ddr_cke),
      .ddr3_rst_no(ddr_rst_n),
      .ddr3_cs_no(ddr_cs),
      .ddr3_ras_no(ddr_ras),
      .ddr3_cas_no(ddr_cas),
      .ddr3_we_no(ddr_we),
      .ddr3_odt_o(ddr_odt),
      .ddr3_ba_o(ddr_bank),
      .ddr3_a_o(ddr_addr),
      .ddr3_dm_o(ddr_dm),
      .ddr3_dqs_pio(ddr_dqs),
      .ddr3_dqs_nio(ddr_dqs_n),
      .ddr3_dq_io(ddr_dq)
  );

`endif  /* !__gowin_for_the_win */


endmodule  /* tart_ddr3 */
