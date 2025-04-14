`timescale 1ns / 100ps
module top #(
    parameter ANTENNAS = 4,
    localparam XSB = ANTENNAS - 1,
    parameter ID_WIDTH = 4,
    localparam ISB = ID_WIDTH - 1,
    parameter AXI_WIDTH = 32,
    localparam MSB = AXI_WIDTH - 1,
    parameter AXI_KEEPS = AXI_WIDTH / 8,
    localparam SSB = AXI_KEEPS - 1,
    parameter AXI_ADDRS = 27,
    localparam ASB = AXI_ADDRS - 1
) (
    // -- Global 16.368 MHz clock oscillator -- //
    input CLK_16,
    input clk_26,
    input rst_n,   // Button 'S2' on the Sipeeed Tang Primer 20k dev-board

    input send_n,  // 'S4' button for UART read-back

    input  uart_rx,  // '/dev/ttyUSB1'
    output uart_tx,

    // -- SPI interface to the RPi -- //
    input  SCLK,
    output MISO,
    input  MOSI,
    input  CS,

    // -- Radio signals -- //
    // output RADIO_RECONFIG,
    // input [ANTENNAS-1:0] I1,
    // input [ANTENNAS-1:0] Q1,

    // -- USB PHY (ULPI) -- //
    output       ulpi_rst,
    input        ulpi_clk,
    input        ulpi_dir,
    input        ulpi_nxt,
    output       ulpi_stp,
    inout  [7:0] ulpi_data,

    // 1Gb DDR3 SDRAM pins
    output ddr_ck,
    // output ddr_ck_n,
    output ddr_cke,
    output ddr_rst_n,
    output ddr_cs,
    output ddr_ras,
    output ddr_cas,
    output ddr_we,
    output ddr_odt,
    output [2:0] ddr_bank,
    output [13:0] ddr_addr,
    output [1:0] ddr_dm,
    inout [1:0] ddr_dqs,
    // inout [1:0] ddr_dqs_n,
    inout [15:0] ddr_dq
);

  //
  //  Some Constants
  ///

  localparam integer COUNT_VALUE = 13_499_999;  // The number of times needed to time 0.5S
  localparam SRAM_BYTES = 2048;

  // -- USB Settings -- //

  localparam DEBUG = 1;
  localparam USE_EP4_OUT = 1;

  parameter [15:0] VENDOR_ID = 16'hF4CE;
  parameter integer VENDOR_LENGTH = 19;
  localparam integer VSB = VENDOR_LENGTH * 8 - 1;
  parameter [VSB:0] VENDOR_STRING = "University of Otago";

  parameter [15:0] PRODUCT_ID = 16'h0003;
  parameter integer PRODUCT_LENGTH = 8;
  localparam integer PSB = PRODUCT_LENGTH * 8 - 1;
  parameter [PSB:0] PRODUCT_STRING = "TART USB";

  parameter integer SERIAL_LENGTH = 8;
  localparam integer NSB = SERIAL_LENGTH * 8 - 1;
  parameter [NSB:0] SERIAL_STRING = "TART0001";

  // USB-core end-point configuration
  localparam ENDPOINT1 = 4'd1;
  localparam ENDPOINT2 = 4'd2;
  localparam ENDPOINT3 = 4'd3;
  localparam ENDPOINT4 = 4'd4;

  // Maximum packet lengths for each packet-type (up to 1024 & 64, respectively)
  localparam integer MAX_PACKET_LENGTH = 512;
  localparam integer MAX_CONFIG_LENGTH = 64;

  // -- DDR3 SDRAM Parameters -- //

  // DDR3 Settings //
  localparam DDR3_WIDTH = 32;
  localparam DFIFO_BYPASS = 1;

  // So 16.368 MHz divided by 1, then x15 = 245.52 MHz.
  localparam DDR_FREQ_MHZ = 125;
  localparam CLK_IN_FREQ = "16.368";
  localparam CLK_IDIV_SEL = 0;
  localparam CLK_FBDV_SEL = 14;
  localparam CLK_ODIV_SEL = 4;  // 8 ??
  localparam CLK_SDIV_SEL = 2;

  localparam WRITE_DELAY = 2'b01;  // In 1/4-cycle increments
  localparam PHY_WR_DELAY = 3;
  localparam PHY_RD_DELAY = 2;

  assign uart_tx = 1'b1;


  //
  //  PLL Signals, Clocks, and Resets
  ///

  wire axi_clock, axi_reset;
  wire usb_clock, usb_reset;
  wire vis_clock, vis_reset;
  wire sig_clock, sig_reset;

  // Synchronous reset (active 'LO') for the correlator unit.
  sync_reset #(
      .N(2)
  ) U_VISRST (
      .clock(vis_clock),  // Default: 245.52 MHz
      .arstn(rst_n),
      .reset(vis_reset)
  );


  //
  //  TART Brains
  ///

  wire viz_tvalid, viz_tready, viz_tkeep, viz_tlast;
  wire ctl_tvalid, ctl_tready, ctl_tlast;
  wire res_tvalid, res_tready, res_tkeep, res_tlast;
  wire [7:0] viz_tdata, ctl_tdata, res_tdata;
  wire capture_en_w, acquire_en_w, correlator_w, visb_ready_w, ddr3_ready_w;

  wire configured, crc_error_w, m2u_tkeep;

  assign visb_ready_w = viz_tvalid;

  // TART Configuration //
  controller #(
      .WIDTH(8)
  ) U_CTRL1 (
      .clock_in (CLK_16),
      .areset_n (rst_n),
      .sig_clk_o(sig_clock),
      .sig_rst_o(sig_reset),

      .bus_clock(usb_clock),
      .bus_reset(usb_reset),

      .s_tvalid(ctl_tvalid),
      .s_tready(ctl_tready),
      .s_tlast (ctl_tlast),
      .s_tdata (ctl_tdata),

      .v_tvalid(viz_tvalid),
      .v_tready(viz_tready),
      .v_tkeep (viz_tkeep),
      .v_tlast (viz_tlast),
      .v_tdata (viz_tdata),

      .m_tvalid(res_tvalid),
      .m_tready(res_tready),
      .m_tlast (res_tlast),
      .m_tkeep (res_tkeep),
      .m_tdata (res_tdata),

      .ddr3_ready_i(ddr3_ready_w),
      .capture_en_o(capture_en_w),
      .acquire_en_o(acquire_en_w),
      .correlator_o(correlator_w),
      .visibility_i(visb_ready_w)
  );


  //
  //  Fake Radios
  ///

  reg [XSB:0] dat_i = {ANTENNAS{1'b0}}, dat_q = {ANTENNAS{1'b0}};
  wire [XSB:0] sig_i, sig_q;

  genvar ant;
  generate
    for (ant = 0; ant < ANTENNAS; ant = ant + 1) begin
      radio_dummy #(
          .ANT_NUM(ant)
      ) r0 (
          .clk16(sig_clock),
          .rst_n(~sig_reset),
          .i1(dat_i[ant]),
          .q1(dat_q[ant]),
          .data_i(sig_i[ant]),
          .data_q(sig_q[ant])
      );
    end
  endgenerate

  always @(posedge sig_clock) begin
    dat_i <= sig_i;
    dat_q <= sig_q;
  end


  //
  //  Signal Acquisition
  ///

  reg [XSB:0] I_data, Q_data;
  reg [XSB:0] count_value_reg;  // counter_value
  reg         count_value_flag;  // IO chaneg flag
  reg         RECONFIG_reg = 1'b0;  // Initial state
  wire [XSB:0] I1, Q1;

  // AXI4 Signals between Acquisition Unit and Memory Controller
  wire acq_awvalid, acq_awready, acq_wvalid, acq_wready, acq_wlast;
  wire acq_bvalid, acq_bready;
  wire [1:0] acq_awburst, acq_bresp;
  wire [7:0] acq_awlen;
  wire [ISB:0] acq_awid, acq_bid;
  wire [SSB:0] acq_wstrb;
  wire [MSB:0] acq_wdata;

  assign RADIO_RECONFIG = RECONFIG_reg;
  assign I1 = dat_i;
  assign Q1 = dat_q;

  // Latch the data
  always @(posedge sig_clock) begin
    if (capture_en_w) begin
      I_data <= I1;
      Q_data <= Q1;
    end
  end

  always @(posedge sig_clock) begin
    if (count_value_reg <= COUNT_VALUE) begin  //not count to 0.5S
      count_value_reg  <= count_value_reg + 1'b1;  // Continue counting
      count_value_flag <= 1'b0;  // No flip flag
    end else begin  //Count to 0.5S
      count_value_reg <= 23'b0;  // Clear counter,prepare for next time counting.
      count_value_flag <= 1'b1;  // Flip flag
      RECONFIG_reg <= I_data[0];
    end
  end

  // Acquire raw data, buffer it, chunk it up into 'CHUNK'-sized packets, and
  // then store these packets of raw-data to the DDR3 SDRAM.
  acquire #(
      .RADIOS(ANTENNAS),
      .SRAM_BYTES(SRAM_BYTES)
  ) U_ACQ1 (
      .sig_clock  (sig_clock),
      .sig_valid_i(acquire_en_w),  // Todo ...
      .sig_last_i (1'b0),
      .sig_idata_i(I_data),
      .sig_qdata_i(Q_data),

      .mem_clock(axi_clock),  // Default: 122.76 MHz
      .mem_reset(axi_reset),

      // AXI4 Raw-data Port
      .axi_awvalid_o(acq_awvalid),  // AXI4 Write Address Channel
      .axi_awready_i(acq_awready),
      .axi_awburst_o(acq_awburst),
      .axi_awlen_o(acq_awlen),
      .axi_awid_o(acq_awid),
      .axi_awaddr_o(acq_awaddr),
      .axi_wvalid_o(acq_wvalid),  // AXI4 Write Data Channel
      .axi_wready_i(acq_wready),
      .axi_wlast_o(acq_wlast),
      .axi_wstrb_o(acq_wstrb),
      .axi_wdata_o(acq_wdata),
      .axi_bvalid_i(acq_bvalid),  // AXI4 Write Response Channel
      .axi_bready_o(acq_bready),
      .axi_bresp_i(acq_bresp),
      .axi_bid_i(acq_bid)
  );


  //
  //  Correlator
  ///

  wire vis_start, vis_frame;

  // Calculate visibilities for 4 antennas, with fixed MUX-inputs, for testing.
  toy_correlator #(
      .WIDTH(4),
      .MUX_N(4),
      .TRATE(30),
      .LOOP0(3),
      .LOOP1(5),
      .ACCUM(32),
      .SBITS(7)
  ) U_COR1 (
      .sig_clock(sig_clock),

      .sig_valid_i(correlator_w),
      .sig_last_i (1'b0),
      .sig_idata_i(I_data),
      .sig_qdata_i(Q_data),

      .vis_clock(vis_clock),
      .vis_reset(vis_reset),

      .vis_start_o(vis_start),
      .vis_frame_o(vis_frame),

      // USB/SPI clock domain signals
      .bus_clock(usb_clock),
      .bus_reset(usb_reset),

      .m_tvalid(viz_tvalid),
      .m_tready(viz_tready),
      .m_tkeep (viz_tkeep),
      .m_tlast (viz_tlast),
      .m_tdata (viz_tdata),

      .bus_revis_o(),
      .bus_imvis_o(),
      .bus_valid_o(),
      .bus_ready_i(1'b0),
      .bus_last_o ()
  );


  //
  //  Output Buses and SRAM's
  ///

  wire m2u_tvalid, m2u_tready, m2u_tlast;
  wire u2m_tvalid, u2m_tready, u2m_tkeep, u2m_tlast;
  wire [7:0] m2u_tdata, u2m_tdata;

  usb_ulpi_core #(
      .VENDOR_ID(VENDOR_ID),
      .VENDOR_LENGTH(VENDOR_LENGTH),
      .VENDOR_STRING(VENDOR_STRING),
      .PRODUCT_ID(PRODUCT_ID),
      .PRODUCT_LENGTH(PRODUCT_LENGTH),
      .PRODUCT_STRING(PRODUCT_STRING),
      .SERIAL_LENGTH(SERIAL_LENGTH),
      .SERIAL_STRING(SERIAL_STRING),
      .ENDPOINT1(ENDPOINT1),
      .ENDPOINT2(ENDPOINT2),
      .MAX_PACKET_LENGTH(MAX_PACKET_LENGTH),
      .MAX_CONFIG_LENGTH(MAX_CONFIG_LENGTH),
      .DEBUG(DEBUG),
      .USE_UART(0),
      .ENDPOINTD(ENDPOINT3),
      .ENDPOINT4(ENDPOINT4),
      .USE_EP4_OUT(USE_EP4_OUT)
  ) U_USB1 (
      .osc_in(CLK_16),
      .arst_n(rst_n),

      .ulpi_clk (ulpi_clk),
      .ulpi_rst (ulpi_rst),
      .ulpi_dir (ulpi_dir),
      .ulpi_nxt (ulpi_nxt),
      .ulpi_stp (ulpi_stp),
      .ulpi_data(ulpi_data),

      // Todo: debug UART signals ...
      .send_ni  (send_n),
      .uart_rx_i(uart_rx),
      .uart_tx_o(),

      .usb_clock_o(usb_clock),
      .usb_reset_o(usb_reset),

      .configured_o(configured),
      .conf_event_o(),
      .conf_value_o(),
      .crc_error_o (crc_error_w),

      .blki_tvalid_i(m2u_tvalid),  // Extra 'BULK IN' EP data-path
      .blki_tready_o(m2u_tready),
      .blki_tlast_i (m2u_tlast),
      .blki_tdata_i (m2u_tdata),

      .blko_tvalid_o(u2m_tvalid),  // USB 'BULK OUT' EP data-path
      .blko_tready_i(u2m_tready),
      .blko_tlast_o (u2m_tlast),
      .blko_tdata_o (u2m_tdata),

      .blkx_tvalid_i(res_tvalid),  // USB 'BULK IN' EP data-path
      .blkx_tready_o(res_tready),
      .blkx_tlast_i (res_tlast),
      .blkx_tdata_i (res_tdata),

      .blky_tvalid_o(ctl_tvalid),  // USB 'BULK OUT' EP data-path
      .blky_tready_i(ctl_tready),
      .blky_tlast_o (ctl_tlast),
      .blky_tdata_o (ctl_tdata)
  );


  //
  //  SDRAM
  ///

  assign ddr_addr[13] = 1'b0;
  assign u2m_tkeep = u2m_tvalid;

  tart_ddr3 #(
      .SRAM_BYTES  (SRAM_BYTES),
      .DATA_WIDTH  (DDR3_WIDTH),
      .DFIFO_BYPASS(DFIFO_BYPASS),
      .PHY_WR_DELAY(PHY_WR_DELAY),
      .PHY_RD_DELAY(PHY_RD_DELAY),
      .CLK_IN_FREQ (CLK_IN_FREQ),
      .CLK_IDIV_SEL(CLK_IDIV_SEL),
      .CLK_FBDV_SEL(CLK_FBDV_SEL),
      .CLK_ODIV_SEL(CLK_ODIV_SEL),
      .CLK_SDIV_SEL(CLK_SDIV_SEL),
      .DDR_FREQ_MHZ(DDR_FREQ_MHZ),
      .LOW_LATENCY (0),
      .WR_PREFETCH (0),
      .WRITE_DELAY (WRITE_DELAY)
  ) U_DDR1 (
      .osc_in(CLK_16),  // TART radio clock, 16.368 MHz
      .arst_n(rst_n),   // 'S2' button for async-reset

      .bus_clock(usb_clock),
      .bus_reset(usb_reset),

      .ddr3_conf_o(ddr3_ready_w),
      .ddr_clkx2_o(vis_clock),  // (default: 245.52 MHz)
      .ddr_clock_o(axi_clock),  // (default: 122.76 MHz)
      .ddr_reset_o(axi_reset),

      // From USB or SPI (default: 60.0 MHz)
      .s_tvalid(u2m_tvalid),
      .s_tready(u2m_tready),
      .s_tkeep (u2m_tkeep),
      .s_tlast (u2m_tlast),
      .s_tdata (u2m_tdata),

      // To USB or SPI (default: 60.0 MHz)
      .m_tvalid(m2u_tvalid),
      .m_tready(m2u_tready),
      .m_tkeep (m2u_tkeep),
      .m_tlast (m2u_tlast),
      .m_tdata (m2u_tdata),

      // Acquired raw radio data to the DDR3 controller
      .axi_awvalid_i(acq_awvalid),
      .axi_awready_o(acq_awready),
      .axi_awaddr_i(acq_awaddr),
      .axi_awid_i(acq_awid),
      .axi_awlen_i(acq_awlen),
      .axi_awburst_i(acq_awburst),

      .axi_wvalid_i(acq_wvalid),
      .axi_wready_o(acq_wready),
      .axi_wlast_i (acq_wlast),
      .axi_wstrb_i (acq_wstrb),
      .axi_wdata_i (acq_wdata),

      .axi_bvalid_o(acq_bvalid),
      .axi_bready_i(acq_bready),
      .axi_bresp_o(acq_bresp),
      .axi_bid_o(acq_bid),

      // 1Gb DDR3 SDRAM pins
      .ddr_ck(ddr_ck),
      .ddr_ck_n(),
      .ddr_cke(ddr_cke),
      .ddr_rst_n(ddr_rst_n),
      .ddr_cs(ddr_cs),
      .ddr_ras(ddr_ras),
      .ddr_cas(ddr_cas),
      .ddr_we(ddr_we),
      .ddr_odt(ddr_odt),
      .ddr_bank(ddr_bank),
      .ddr_addr(ddr_addr[12:0]),
      .ddr_dm(ddr_dm),
      .ddr_dqs(ddr_dqs),
      .ddr_dqs_n(),
      .ddr_dq(ddr_dq)
  );


endmodule  /* top */
