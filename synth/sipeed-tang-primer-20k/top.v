`timescale 1ns / 100ps
module top #(
    parameter ANTENNAS = 24,
    localparam ASB = ANTENNAS - 1,
    parameter AXI_WIDTH = 8
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
  localparam LOOPBACK = 1;
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
  localparam integer SSB = SERIAL_LENGTH * 8 - 1;
  parameter [SSB:0] SERIAL_STRING = "TART0001";

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

  wire axi_clock, axi_reset, bus_reset;
  wire usb_clock, usb_reset, usb_rst_n;
  wire vis_clock, vis_reset, mem_reset;

  assign bus_reset = axi_reset;
  assign usb_rst_n = ~usb_reset;

`ifdef __do_not_use_ddr3

  wire axi_lock, vis_lock;

  // So 27.0 MHz divided by 9, then x40 = 120 MHz.
  gowin_rpll #(
      .FCLKIN("27"),
      .IDIV_SEL(8),  // ~=  9
      .FBDIV_SEL(39),  // ~= 40
      .ODIV_SEL(8)
  ) axi_rpll_inst (
      .clkout(axi_clock),  // 120 MHz
      .lock  (),
      .clkin (clk_26)
  );

  // Correlator clock domain runs at 15x the global clock for the radios.
  // Also used as the DDR3 clock
  gowin_rpll #(
      .FCLKIN("16.368"),
      .IDIV_SEL(0),  // ~=  1
      .FBDIV_SEL(14),  // ~= 15
      .ODIV_SEL(8)
  ) vis_rpll_inst (
      .clkout(vis_clock),  // 245.52 MHz
      .lock  (vis_lock),
      .clkin (CLK_16)
  );

`endif  /* __do_not_use_ddr3 */

  // -- Resets -- //

  // Synchronous reset signal (when 'HI'), for the AXI clock-domain.
  sync_reset #(
      .N(2)
  ) U_AXI_RESET (
      .clock(axi_clock),
      .arstn(~rst_n),
      .reset(axi_reset)
  );

  // Synchronous reset (active 'LO') for the correlator unit.
  sync_reset #(
      .N(2)
  ) U_VIS_RESET (
      .clock(vis_clock),
      .arstn(~rst_n),
      .reset(vis_reset)
  );


  //
  //  Signal Acquisition
  ///

  wire [ASB:0] I1, Q1;

  reg [ASB:0] I_data, Q_data;
  reg [ASB:0] count_value_reg;  // counter_value
  reg         count_value_flag;  // IO chaneg flag
  reg         RECONFIG_reg = 1'b0;  // Initial state

  assign RADIO_RECONFIG = RECONFIG_reg;

  // Latch the data
  always @(posedge CLK_16) begin
    I_data <= I1;
    Q_data <= Q1;
  end

  always @(posedge CLK_16) begin
    if (count_value_reg <= COUNT_VALUE) begin  //not count to 0.5S
      count_value_reg  <= count_value_reg + 1'b1;  // Continue counting
      count_value_flag <= 1'b0;  // No flip flag
    end else begin  //Count to 0.5S
      count_value_reg <= 23'b0;  // Clear counter,prepare for next time counting.
      count_value_flag <= 1'b1;  // Flip flag
      RECONFIG_reg <= I_data[0];
    end
  end


  //
  //  Correlator
  ///

  wire vis_start, vis_frame, ddr3_conf_w;

  // Calculate visibilities for 4 antennas, with fixed MUX-inputs, for testing.
  toy_correlator #(
      .WIDTH(4),
      .MUX_N(4),
      .TRATE(30),
      .LOOP0(3),
      .LOOP1(5),
      .ACCUM(32),
      .SBITS(7)
  ) tart_correlator_inst (
      .sig_clock(CLK_16),
      .bus_clock(usb_clock),
      .bus_reset(usb_reset),

      .vis_clock(vis_clock),
      .vis_reset(vis_reset),

      .sig_valid_i(ddr3_conf_w),
      .sig_last_i (1'b0),
      .sig_idata_i(I_data),
      .sig_qdata_i(Q_data),

      .vis_start_o(vis_start),
      .vis_frame_o(vis_frame),

      .bus_revis_o(),
      .bus_imvis_o(),
      .bus_valid_o(),
      .bus_ready_i(1'b0),
      .bus_last_o ()
  );


  //
  //  Output Buses and SRAM's
  ///

  // -- USB ULPI Bulk transfer endpoint (IN & OUT) -- //

  //
  // Todo:
  //  - MMIO interface to TART top-level control module ??
  //  - better plumbing to DDR3 controller;
  //
  wire m2u_tvalid, m2u_tready, m2u_tlast, u2m_tvalid, u2m_tready, u2m_tkeep, u2m_tlast;
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

      .blkx_tvalid_i(LOOPBACK ? m_tvalid : s_tvalid),  // USB 'BULK IN' EP data-path
      .blkx_tready_o(s_tready),
      .blkx_tlast_i (LOOPBACK ? m_tlast : s_tlast),
      .blkx_tdata_i (LOOPBACK ? m_tdata : s_tdata),

      .blky_tvalid_o(m_tvalid),  // USB 'BULK OUT' EP data-path
      .blky_tready_i(LOOPBACK ? s_tready : m_tready),
      .blky_tlast_o(m_tlast),
      .blky_tdata_o(m_tdata)
  );

  // -- Cross Between USB & AXI/DDR Clock Domans -- //

  /*
  axis_afifo #(
      .WIDTH(8),
      .TLAST(1),
      .ABITS(4)
  ) U_FIFO1 (
      .aresetn(~usb_reset),

      .s_aclk  (usb_clock),
      .s_tvalid(y_tvalid),
      .s_tready(y_tready),
      .s_tlast (y_tlast),
      .s_tdata (y_tdata),

      .m_aclk  (axi_clock),
      .m_tvalid(u2m_tvalid),
      .m_tready(u2m_tready),
      .m_tlast (u2m_tlast),
      .m_tdata (u2m_tdata)
  );

  axis_afifo #(
      .WIDTH(8),
      .TLAST(1),
      .ABITS(4)
  ) U_FIFO2 (
      .aresetn(~usb_reset),

      .s_aclk  (axi_clock),
      .s_tvalid(m2u_tvalid),
      .s_tready(m2u_tready),
      .s_tlast (m2u_tlast),
      .s_tdata (m2u_tdata),

      .m_aclk  (usb_clock),
      .m_tvalid(x_tvalid),
      .m_tready(x_tready),
      .m_tlast (x_tlast),
      .m_tdata (x_tdata)
  );
*/

  //
  //  SDRAM
  ///

  //
  // Todo:
  //  - needs additional read- & write- ports, for radio-signals;
  //  - plumb in the asynchronous FIFOs (above), for USB requests;
  //

  assign ddr_addr[13] = 1'b0;
  assign u2m_tkeep = u2m_tvalid;

  ddr3_top #(
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

      .ddr3_conf_o(ddr3_conf_w),
      .ddr_clkx2_o(vis_clock),
      .ddr_clock_o(axi_clock),
      .ddr_reset_o(mem_reset),

      // From USB or SPI
      .s_tvalid(u2m_tvalid),
      .s_tready(u2m_tready),
      .s_tkeep (u2m_tkeep),
      .s_tlast (u2m_tlast),
      .s_tdata (u2m_tdata),

      // To USB or SPI
      .m_tvalid(m2u_tvalid),
      .m_tready(m2u_tready),
      .m_tkeep (m2u_tkeep),
      .m_tlast (m2u_tlast),
      .m_tdata (m2u_tdata),

      // 1Gb DDR3 SDRAM pins
      .ddr_ck(ddr_ck),
      // .ddr_ck_n(ddr_ck_n),
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
      // .ddr_dqs_n(ddr_dqs_n),
      .ddr_dq(ddr_dq)
  );


endmodule  /* top */
