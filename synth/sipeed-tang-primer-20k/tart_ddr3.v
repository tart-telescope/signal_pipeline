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
    parameter SRAM_BYTES   = 2048,
    parameter DATA_WIDTH   = 32,
    parameter DFIFO_BYPASS = 0,

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
    input arst_n,  // 'S2' button for async-reset

    input bus_clock,
    input bus_reset,

    output ddr3_conf_o,
    output ddr_reset_o,
    output ddr_clock_o,
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

    // Raw data port
    input axi_awvalid_i,  // AXI4 Write Address Port
    output axi_awready_o,
    input [ASB:0] axi_awaddr_i,
    input [ISB:0] axi_awid_i,
    input [7:0] axi_awlen_i,
    input [1:0] axi_awburst_i,
    input axi_wvalid_i,  // AXI4 Write Data Port
    output axi_wready_o,
    input [MSB:0] axi_wdata_i,
    input [SSB:0] axi_wstrb_i,
    input axi_wlast_i,
    output axi_bvalid_o,  // AXI4 Write Response
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
    output [12:0] ddr_addr,
    output [1:0] ddr_dm,
    inout [1:0] ddr_dqs,
    inout [1:0] ddr_dqs_n,
    inout [15:0] ddr_dq
);

  // -- Constants -- //

  // Data-path widths
  localparam DDR_DQ_WIDTH = 16;
  localparam DSB = DDR_DQ_WIDTH - 1;

  localparam DDR_DM_WIDTH = 2;
  localparam QSB = DDR_DM_WIDTH - 1;

  // Address widths
  localparam DDR_ROW_BITS = 13;
  localparam RSB = DDR_ROW_BITS - 1;

  localparam DDR_COL_BITS = 10;
  localparam CSB = DDR_COL_BITS - 1;

  localparam WIDTH = 32;
  localparam MSB = WIDTH - 1;
  localparam MASKS = WIDTH / 8;
  localparam BSB = MASKS - 1;

  // note: (AXI4) byte address, not burst-aligned address
  localparam ADDRS = DDR_COL_BITS + DDR_ROW_BITS + 4;
  localparam ASB = ADDRS - 1;

  localparam REQID = 4;
  localparam ISB = REQID - 1;


  // -- DDR3 Core and AXI Interconnect Signals -- //

  // AXI4 Signals to/from the Memory Controller
  wire awvalid, wvalid, wlast, bready, arvalid_w, rready_w;
  wire awready, wready, bvalid, arready_w, rvalid_w, rlast_w;
  wire [ISB:0] awid, arid_w, bid, rid_w;
  wire [7:0] awlen, arlen_w;
  wire [1:0] awburst, arburst_w;
  wire [ASB:0] awaddr, araddr_w;
  wire [BSB:0] wstrb;
  wire [1:0] bresp, rresp_w;
  wire [MSB:0] rdata_w, wdata;

  // DFI <-> PHY
  wire dfi_rst_n, dfi_cke, dfi_cs_n, dfi_ras_n, dfi_cas_n, dfi_we_n;
  wire dfi_odt, dfi_wstb, dfi_wren, dfi_rden, dfi_valid, dfi_last;
  wire [  2:0] dfi_bank;
  wire [RSB:0] dfi_addr;
  wire [BSB:0] dfi_mask;
  wire [MSB:0] dfi_wdata, dfi_rdata;

  wire dfi_calib, dfi_align;
  wire [2:0] dfi_shift;

  wire clk_x2, clk_x1, locked;
  wire clock, reset;

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
  // always #2.5 dclk <= ~dclk;
  // always #5.0 mclk <= ~mclk;
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

  memreq #(
      .FIFO_DEPTH(SRAM_BYTES * 8 / DATA_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .STROBES(DATA_WIDTH / 8),
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
      .awvalid_o(awvalid),
      .awready_i(awready),
      .awaddr_o(awaddr),
      .awid_o(awid),
      .awlen_o(awlen),
      .awburst_o(awburst),

      .wvalid_o(wvalid),
      .wready_i(wready),
      .wlast_o (wlast),
      .wstrb_o (wstrb),
      .wdata_o (wdata),

      .bvalid_i(bvalid),
      .bready_o(bready),
      .bresp_i(bresp),
      .bid_i(bid),

      // Read -address & -data ports(), to/from the DDR3 controller
      .arvalid_o(arvalid_w),
      .arready_i(arready_w),
      .araddr_o(araddr_w),
      .arid_o(arid_w),
      .arlen_o(arlen_w),
      .arburst_o(arburst_w),

      .rvalid_i(rvalid_w),
      .rready_o(rready_w),
      .rlast_i(rlast_w),
      .rresp_i(rresp_w),
      .rid_i(rid_w),
      .rdata_i(rdata_w)
  );

  // Todo ...
  reg mux_q = 0;
  reg sel_q = 1;
  wire mux_tvalid, mux_tready, mux_tkeep, mux_tlast;
  wire [7:0] mux_tdata;

  // Multiplexor for write-data from the SPI or USB core
  axis_mux #(
      .S_COUNT(2),
      .DATA_WIDTH(8),
      .KEEP_ENABLE(1),
      .KEEP_WIDTH(1),
      .ID_ENABLE(0),
      .ID_WIDTH(1),
      .DEST_ENABLE(0),
      .DEST_WIDTH(1),
      .USER_ENABLE(0),
      .USER_WIDTH(1)
  ) U_MUX1 (
      .clk(bus_clock),
      .rst(bus_reset),

      .enable(mux_q),
      .select(sel_q),

      .s_axis_tvalid({raw_tvalid, u2m_tvalid}), // AXI input: 2x 8b
      .s_axis_tready({raw_tready, u2m_tready}),
      .s_axis_tkeep ({raw_tkeep, u2m_tkeep}),
      .s_axis_tlast ({raw_tlast, u2m_tlast}),
      .s_axis_tuser (2'bx),
      .s_axis_tid   (2'bx),
      .s_axis_tdest (2'bx),
      .s_axis_tdata ({raw_tdata, u2m_tdata}),

      .m_axis_tvalid(mux_tvalid), // AXI output: 8b
      .m_axis_tready(mux_tready),
      .m_axis_tkeep (mux_tkeep),
      .m_axis_tlast (mux_tlast),
      .m_axis_tuser (),
      .m_axis_tid   (),
      .m_axis_tdest (),
      .m_axis_tdata (mux_tdata)
  );


  //
  //  DDR Core Under New Test
  ///

  localparam BYPASS_ENABLE = RD_FASTPATH;

  wire [QSB:0] dfi_dqs_p, dfi_dqs_n;
  wire [1:0] dfi_wrdly;
  wire [2:0] dfi_rddly;

  wire crvalid, crready, cvalid, cready, clast;
  wire [1:0] crburst, cresp;
  wire [  7:0] crlen;
  wire [ASB:0] craddr;
  wire [ISB:0] crid, cid;
  wire [MSB:0] cdata;

  wire arvalid, arready, rvalid, rready, rlast;
  wire [1:0] arburst, rresp;
  wire [  7:0] arlen;
  wire [ASB:0] araddr;
  wire [ISB:0] arid, rid;
  wire [MSB:0] rdata;

  axi_ddr3_lite #(
      .DDR_FREQ_MHZ    (DDR_FREQ_MHZ),
      .DDR_ROW_BITS    (DDR_ROW_BITS),
      .DDR_COL_BITS    (DDR_COL_BITS),
      .DDR_DQ_WIDTH    (DDR_DQ_WIDTH),
      .PHY_WR_DELAY    (PHY_WR_DELAY),
      .PHY_RD_DELAY    (PHY_RD_DELAY),
      .WR_PREFETCH     (WR_PREFETCH),
      .LOW_LATENCY     (LOW_LATENCY),
      .AXI_ID_WIDTH    (REQID),
      .MEM_ID_WIDTH    (REQID),
      .DFIFO_BYPASS    (DFIFO_BYPASS),
      .USE_PACKET_FIFOS(0)
  ) U_LITE (
      .arst_n(arst_n),  // Global, asynchronous reset

      .clock(clock),  // system clock
      .reset(reset),  // synchronous reset

      .configured_o(ddr3_conf_o),

      .axi_awvalid_i(awvalid),
      .axi_awready_o(awready),
      .axi_awaddr_i(awaddr),
      .axi_awid_i(awid),
      .axi_awlen_i(awlen),
      .axi_awburst_i(awburst),

      .axi_wvalid_i(wvalid),
      .axi_wready_o(wready),
      .axi_wlast_i (wlast),
      .axi_wstrb_i (wstrb),
      .axi_wdata_i (wdata),

      .axi_bvalid_o(bvalid),
      .axi_bready_i(bready),
      .axi_bresp_o(bresp),
      .axi_bid_o(bid),

      .axi_arvalid_i(arvalid),
      .axi_arready_o(arready),
      .axi_araddr_i(araddr),
      .axi_arid_i(arid),
      .axi_arlen_i(arlen),
      .axi_arburst_i(arburst),

      .axi_rvalid_o(rvalid_w),
      .axi_rready_i(rready_w),
      .axi_rlast_o(rlast_w),
      .axi_rresp_o(rresp_w),
      .axi_rid_o(rid_w),
      .axi_rdata_o(rdata_w),

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
