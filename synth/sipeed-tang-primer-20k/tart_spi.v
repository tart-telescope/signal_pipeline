`timescale 1ns / 100ps
module tart_spi (
                 );

  // SPI clock, 24.0 MHz.
  wire clock_b;

  gowin_clkdiv #(
      .DIV_MODE("5")
  ) gowin_clkdiv_inst (
      .hclkin(axi_clock),
      .resetn(axi_lock),
      .clkout(clock_b)
  );

  // Synchronous reset (active 'LO') for the SPI unit.

  sync_reset #(
      .N(2)
  ) bus_sync_reset (
      .clk(clock_b),
      .rst(rst_n),
      .out(bus_rst_n)
  );

localparam integer USE_SPI = 0;
localparam integer USE_USB = 0;
localparam integer USE_UART = 1;
localparam integer USE_LOOP = 0;


  // -- SPI connection to RPi -- //
generate if (USE_SPI) begin : g_use_spi

  localparam integer PIPED = 1;
  localparam integer CHECK = 1;

  wire spi_rty, spi_err;
  wire [7:0] spi_drx;

  wire sys_status;
  wire spi_busy, spi_oflow, spi_uflow;

  wire spi_rst = ~bus_rst_n;

  assign spi_rty = 1'b0;
  assign spi_err = 1'b0;

  spi_slave_wb #(
      .WIDTH(8),
      .ASYNC(1),
      .PIPED(PIPED),
      .CHECK(CHECK)
  ) SPI0 (
      .clk_i(clock_b),
      .rst_i(spi_rst),

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
end  // g_use_spi
endgenerate

  wire spi_stb, spi_ack, spi_cyc, spi_we;
  wire [15:0] spi_adr;
  wire [31:0] spi_real, spi_imag;

  reg spi_wat = 1'b0;
  reg [7:0] spi_dtx;

  always @(posedge clock_b) begin
    case (spi_adr[15:13])
      3'b000:  spi_dtx <= spi_real[31:24];
      3'b001:  spi_dtx <= spi_real[23:16];
      3'b010:  spi_dtx <= spi_real[15:8];
      3'b011:  spi_dtx <= spi_real[7:0];
      3'b100:  spi_dtx <= spi_imag[31:24];
      3'b101:  spi_dtx <= spi_imag[23:16];
      3'b110:  spi_dtx <= spi_imag[15:8];
      3'b111:  spi_dtx <= spi_imag[7:0];
      default: $error("Yuck!");
    endcase
    spi_wat <= ~spi_ack;
  end

endmodule  /* tart_spi */
