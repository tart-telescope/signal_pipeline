`timescale 1ns / 100ps
module acquire #(
    parameter RADIOS = 24,
    localparam XSB = RADIOS - 1,
    parameter SRAM_BYTES = 2048,
    parameter AXI_WIDTH = 32,
    localparam MSB = AXI_WIDTH - 1,
    localparam AXI_KEEPS = AXI_WIDTH / 8,
    localparam SSB = AXI_KEEPS - 1,
    parameter AXI_IDNUM = 4,
    localparam ISB = AXI_IDNUM - 1,
    parameter AXI_ADDRS = 27,
    localparam ASB = AXI_ADDRS - 1,
    parameter CHUNK = 512 * 8 / AXI_WIDTH,
    parameter ADDR_STEP = CHUNK * AXI_WIDTH / 8
) (
    input sig_clock,
    input sig_reset,

    // AXI4 Stream of antenna data
    input sig_valid_i,
    input sig_last_i,
    input [XSB:0] sig_idata_i,
    input [XSB:0] sig_qdata_i,

    input mem_clock,
    input mem_reset,

    // AXI4 Raw-data Port
    output axi_awvalid_o,  // AXI4 Write Address Channel
    input axi_awready_i,
    output [ASB:0] axi_awaddr_o,
    output [ISB:0] axi_awid_o,
    output [7:0] axi_awlen_o,
    output [1:0] axi_awburst_o,
    output axi_wvalid_o,  // AXI4 Write Data Channel
    input axi_wready_i,
    output axi_wlast_o,
    output [SSB:0] axi_wstrb_o,
    output [MSB:0] axi_wdata_o,
    input axi_bvalid_i,  // AXI4 Write Response Channel
    output axi_bready_o,
    input [1:0] axi_bresp_i,
    input [ISB:0] axi_bid_i
);

  // -- Constants -- //

  `include "axi_defs.vh"

  localparam RAD_KEEPS = (RADIOS * 2 + 7) / 8;
  localparam RAD_WIDTH = RAD_KEEPS << 3;
  localparam WSB = RAD_WIDTH - 1;
  localparam KSB = RAD_KEEPS - 1;

  localparam ACQ_ID = 4'd1;  // Todo ...

  localparam SRAM_DEPTH = SRAM_BYTES / AXI_WIDTH;

  // -- Signals & State -- //

  reg avld_q, xfer_q, save_q, next_q, busy_q;
  reg [ASB:0] addr_q;
  wire save_w;
  wire [AXI_ADDRS:0] addr_w;

  wire tvalid_w, tready_w, tlast_w, xvalid_w, xready_w, xkeep_w, xlast_w;
  wire [KSB:0] tkeep_w;
  wire [WSB:0] tdata_w;
  wire [  7:0] xdata_w;

  wire pvalid_w, pready_w, plast_w;
  wire [SSB:0] pkeep_w;
  wire [MSB:0] pdata_w;

  // -- Module Input & Output Assignments -- //

  assign axi_awvalid_o = avld_q;
  assign axi_awlen_o = CHUNK;
  assign axi_awburst_o = BURST_TYPE_INCR;
  assign axi_awid_o = ACQ_ID;
  assign axi_awaddr_o = addr_q;

  assign axi_wvalid_o = pvalid_w;
  assign pready_w = xfer_q && axi_wready_i;
  assign axi_wlast_o = plast_w;
  assign axi_wstrb_o = pkeep_w;
  assign axi_wdata_o = pdata_w;

  // -- Internal Assignments -- //

  assign pkeep_w = {AXI_KEEPS{pvalid_w}};
  assign tkeep_w = {RAD_KEEPS{tvalid_w}};

  // -- Signal-Domain Acquisition Logic -- //

  //
  // Todo:
  //  - generate a 'save' when 'sig_valid_i' deasserts;
  //  - the following implementation is one-cycle-too-late !?
  //
  always @(posedge sig_clock) begin
    if (sig_reset) begin
      save_q <= 1'b0;
      busy_q <= 1'b0;
    end else begin
      if (!sig_valid_i && busy_q) begin
        save_q <= 1'b1;
      end else begin
        save_q <= 1'b0;
      end
      busy_q <= sig_valid_i;
    end
  end

  // -- AXI Write-Address Circuit -- //

  assign addr_w = addr_q + ADDR_STEP;

  always @(posedge mem_clock) begin
    if (mem_reset) begin
      avld_q <= 1'b0;
      xfer_q <= 1'b0;
      next_q <= 1'b0;
      addr_q <= {AXI_ADDRS{1'b0}};
    end else begin
      if (pvalid_w && pready_w && plast_w) begin
        avld_q <= 1'b1;
        xfer_q <= 1'b0;
        next_q <= 1'b0;
        addr_q <= addr_w[ASB:0];
      end else if (avld_q && axi_awready_i) begin
        avld_q <= 1'b0;
        xfer_q <= 1'b1;
        next_q <= 1'b0;
        addr_q <= addr_q;
      end else if (axi_wvalid_o && axi_wready_i && axi_wlast_o) begin
        avld_q <= 1'b0;
        xfer_q <= 1'b0;
        next_q <= 1'b1;
        addr_q <= addr_q;
      end else begin
        avld_q <= avld_q;
        xfer_q <= xfer_q;
        next_q <= 1'b0;
        addr_q <= addr_q;
      end
    end
  end

  // Transfer from signal-domain (default: 16.368 MHz) to the memory controller
  // clock-domain (default: 122.76 MHz)
  axis_afifo #(
      .WIDTH(RAD_WIDTH),
      .TLAST(0),
      .ABITS(4)
  ) U_AFIFO1 (
      .aresetn(~mem_reset),
      .s_aclk(sig_clock),
      .s_tvalid(sig_valid_i),
      .s_tready(),
      .s_tlast(sig_last_i & sig_valid_i | save_q),
      .s_tdata({sig_qdata_i, sig_idata_i}),
      .m_aclk(mem_clock),
      .m_tvalid(tvalid_w),
      .m_tready(tready_w),
      .m_tlast(save_w),  // Todo ...
      .m_tdata(tdata_w)
  );

  axis_adapter #(
      .S_DATA_WIDTH(AXI_WIDTH),
      .S_KEEP_ENABLE(1),
      .S_KEEP_WIDTH(AXI_KEEPS),
      .M_DATA_WIDTH(RAD_WIDTH),
      .M_KEEP_ENABLE(1),
      .M_KEEP_WIDTH(RAD_KEEPS),
      .ID_ENABLE(0),
      .ID_WIDTH(1),
      .DEST_ENABLE(0),
      .DEST_WIDTH(1),
      .USER_ENABLE(0),
      .USER_WIDTH(1)
  ) U_ADAPT1 (
      .clk(mem_clock),
      .rst(mem_reset),

      .s_axis_tvalid(tvalid_w),  // AXI input
      .s_axis_tready(tready_w),
      .s_axis_tkeep(tkeep_w),
      .s_axis_tlast(1'b0),
      .s_axis_tid(1'b0),
      .s_axis_tdest(1'b0),
      .s_axis_tuser(1'b0),
      .s_axis_tdata(tdata_w),

      .m_axis_tvalid(xvalid_w),
      .m_axis_tready(xready_w),
      .m_axis_tkeep(xkeep_w),
      .m_axis_tlast(),
      .m_axis_tid(),
      .m_axis_tdest(),
      .m_axis_tuser(),
      .m_axis_tdata(xdata_w)  // AXI output
  );

  packet_fifo #(
      .WIDTH(AXI_WIDTH),
      .DEPTH(SRAM_DEPTH),
      .STORE_LASTS(1),
      .SAVE_ON_LAST(1),
      .LAST_ON_SAVE(0),
      .NEXT_ON_LAST(0),
      .USE_LENGTH(1),
      .MAX_LENGTH(CHUNK),
      .OUTREG(2)
  ) U_PFIFO1 (
      .clock(mem_clock),
      .reset(mem_reset),

      .level_o(),
      .drop_i (1'b0),
      .save_i (1'b0),
      .redo_i (1'b0),
      .next_i (next_q),

      .s_tvalid(xvalid_w),
      .s_tready(xready_w),
      .s_tkeep (xkeep_w),
      .s_tlast (1'b0),
      .s_tdata (xdata_w),

      .m_tvalid(pvalid_w),
      .m_tready(pready_w),
      .m_tlast (plast_w),
      .m_tdata (pdata_w)
  );


endmodule  /* acquire */
