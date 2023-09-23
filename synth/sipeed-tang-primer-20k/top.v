`timescale 1ns / 100ps
module top #(
    parameter ANTENNAS = 24,
    parameter WB_DATA_BITS = 8
) (
    // -- Global 16.368 MHz clock oscillator -- //
    input CLK_16,
    input clk_26,
    input rst_n,

    // -- SPI interface to the RPi -- //
    input  SCLK,
    output MISO,
    input  MOSI,
    input  CS,

    // -- Radio signals -- //
    output RADIO_RECONFIG,
    input [ANTENNAS-1:0] I1,
    input [ANTENNAS-1:0] Q1,

    // -- USB PHY (ULPI) -- //
    output wire       ulpi_rst,
    input  wire       ulpi_clk,
    input  wire       ulpi_dir,
    input  wire       ulpi_nxt,
    output wire       ulpi_stp,
    inout  wire [7:0] ulpi_data
);

  localparam FPGA_VENDOR = "gowin";
  localparam FPGA_FAMILY = "gw2a";
  localparam [63:0] SERIAL_NUMBER = "FACE0123";

  localparam HIGH_SPEED = 1'b1;
  localparam CHANNEL_IN_ENABLE = 1'b1;
  localparam CHANNEL_OUT_ENABLE = 1'b1;
  localparam PACKET_MODE = 1'b0;

  localparam integer COUNT_VALUE = 13_499_999;  // The number of times needed to time 0.5S


  // -- IOBs -- //

  // -- PLL -- //

  wire axi_clk, axi_lock;
  wire usb_clk, usb_rst_n;

  // So 27.0 MHz divided by 9, then x40 = 120 MHz.
  gowin_rpll #(
      .FCLKIN("27"),
      .IDIV_SEL(8),  // ~=  9
      .FBDIV_SEL(39),  // ~= 40
      .ODIV_SEL(8)
  ) gowin_rpll_inst (
      .clkout(axi_clk),   // 120 MHz
      .lock  (axi_lock),
      .clkin (clk_26)
  );


  // -- Globalists -- //

  reg reset_n;
  reg rst_n2, rst_n1, rst_n0;

  always @(posedge axi_clk) begin
    {reset_n, rst_n2, rst_n1, rst_n0} <= {rst_n2, rst_n1, rst_n0, rst_n};
  end

  // SPI clock, 24.0 MHz.
  wire clock_b;

  gowin_clkdiv #(
      .DIV_MODE("5")
  ) gowin_clkdiv_inst (
      .hclkin(axi_clk),
      .resetn(reset_n),
      .clkout(clock_b)
  );


  // -- Acquisition -- //

  reg [23:0] I_data;
  reg [23:0] Q_data;

  reg [23:0] count_value_reg;  // counter_value
  reg        count_value_flag;  // IO chaneg flag
  reg        RECONFIG_reg = 1'b0;  // Initial state

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


  // -- SDRAM -- //

  // -- Correlator -- //

  // -- Output SRAM's -- //


  // -- SPI connection to RPi -- //

  localparam integer PIPED = 1;
  localparam integer CHECK = 1;

  wire spi_cyc, spi_stb, sp_we, spi_ack, spi_wat, spi_rty, spi_err;
  wire [15:0] spi_adr;
  wire [7:0] spi_dtx, spi_drx;

  wire sys_status;
  wire spi_busy, spi_oflow, spi_uflow;

  spi_slave_wb #(
      .WIDTH(8),
      .ASYNC(1),
      .PIPED(1),
      .CHECK(CHECK)
  ) SPI0 (
      .clk_i(clock_b),
      .rst_i(reset_spi),

      //  Wishbone master interface.
      .cyc_o(spi_cyc),
      .stb_o(spi_stb),
      .we_o (spi_we),
      .ack_i(spi_ack),
      .wat_i(spi_wat),
      .rty_i(spi_rty),
      .err_i(spi_err),
      .adr_o(spi_adr),
      .dat_i(spi_dtx),
      .dat_o(spi_drx),

      .active_o  (spi_busy),
      .status_i  (sys_status),
      .overflow_o(spi_oflow),
      .underrun_o(spi_uflow),

      .SCK_pin(SCLK),
      .MOSI   (MOSI),
      .MISO   (MISO),
      .SSEL   (CS)
  );


  // -- USB ULPI Bulk transfer endpoint (IN & OUT) -- //

  wire ulpi_data_t;
  wire [7:0] ulpi_data_o;

  assign ulpi_rst  = usb_rst_n;
  assign usb_clk   = ~ulpi_clk;
  assign ulpi_data = ulpi_data_t ? {8{1'bz}} : ulpi_data_o;

  wire s_tvalid, s_tready, s_tlast;
  wire [7:0] s_tdata;

  wire m_tvalid, m_tready, m_tlast;
  wire [7:0] m_tdata;

  ulpi_bulk_axis #(
      .FPGA_VENDOR(FPGA_VENDOR),
      .FPGA_FAMILY(FPGA_FAMILY),
      .HIGH_SPEED(HIGH_SPEED),
      .SERIAL_NUMBER(SERIAL_NUMBER),
      .CHANNEL_IN_ENABLE(CHANNEL_IN_ENABLE),
      .CHANNEL_OUT_ENABLE(CHANNEL_OUT_ENABLE),
      .PACKET_MODE(PACKET_MODE)
  ) ulpi_bulk_axis_inst (
      .ulpi_clock_i(usb_clk),
      .ulpi_reset_o(usb_rst_n),

      .ulpi_dir_i (ulpi_dir),
      .ulpi_nxt_i (ulpi_nxt),
      .ulpi_stp_o (ulpi_stp),
      .ulpi_data_t(ulpi_data_t),
      .ulpi_data_i(ulpi_data),
      .ulpi_data_o(ulpi_data_o),

      .aclk(axi_clk),
      .aresetn(reset_n),

      .s_axis_tvalid_i(s_tvalid),
      .s_axis_tready_o(s_tready),
      .s_axis_tlast_i (s_tlast),
      .s_axis_tdata_i (s_tdata),

      .m_axis_tvalid_o(m_tvalid),
      .m_axis_tready_i(m_tready),
      .m_axis_tlast_o (m_tlast),
      .m_axis_tdata_o (m_tdata)
  );


  // -- Just echo/loop IN <-> OUT -- //

  axis_afifo #(
      .WIDTH(8),
      .ABITS(4)
  ) axis_afifo_inst (
      .s_aresetn(reset_n),

      .s_aclk    (axi_clk),
      .s_tvalid_i(m_tvalid),
      .s_tready_o(m_tready),
      .s_tlast_i (m_tlast),
      .s_tdata_i (m_tdata),

      .m_aclk    (axi_clk),
      .m_tvalid_o(s_tvalid),
      .m_tready_i(s_tready),
      .m_tlast_o (s_tlast),
      .m_tdata_o (s_tdata)
  );


endmodule  // top
