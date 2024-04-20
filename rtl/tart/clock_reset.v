`timescale 1ns / 100ps
/**
 * Generates all of the dependent clocks from external clock-sources.
 * 
 * USB clocks are optional.
 */
module clock_reset
 #( parameter CAPTURE_8_MHZ = 1, // Else, 16.368 MHz
    parameter VIS_MULTIPLIER = 15, // Run correlators at a multiple of source
    parameter USE_ULPI_USB = 0,
    parameter USE_DDR_SDRAM = 0,
    parameter DDR3_250_MHZ = 0,
    parameter GOWIN_GW2A = 1,
    parameter GOWIN_FCLKIN = "27",
    parameter GOWIN_RPLL_IDIV = 3,
    parameter GOWIN_RPLL_FBDIV = 7,
    parameter GOWIN_RPLL_ODIV = 8,
    parameter GOWIN_RPLL_SDIV = 2
 )
 (
  input  clock_in, // Radio clock, 16.368 MHz
  input  clock_27, // External oscilator, 27.000 MHz
  input  areset_n, // Asynchronous reset (button 2, on Tang Primer)

  // -- Signal-capture clock, 8.184 MHz or 16.368 MHz -- //
  output sig_clock,
  output sig_reset,

  // -- Visibilities-calculation clock, 'n x sig_clock' -- //
  output vis_clock,
  output vis_reset,

  // -- USB ULPI PHY source clock, 60 MHz [OPTIONAL] -- //
  input  ulpi_clock,
  output ulpi_rst_n,

  // -- Bus clock is the same that drives one of USB, SPI, or UART -- //
  output bus_clock, // Either 60 MHz, or something else ...
  output bus_clk2x,
  output bus_reset,

  // -- Clocks and reset for SDRAM's -- //
  output mem_clock, // Typically 100 MHz
  output mem_clk2x,
  output mem_reset
  );


  // -- Signals & State Registers -- //

reg vis_reset;
wire clockp, clockd, clockd3, resetd3, vis_locked, vis_rst_w;


// -- Signal-Capture Reset -- //

  sync_reset #( .N(3) ) U_SIG_RST1 (
                                    .clock(clockp),
                                    .arst_n(areset_n),
                                    .reset(sig_reset));


// -- Visibilities-Calculation Clock & Reset -- //

always @(posedge vis_clock) begin
    vis_reset <= vis_rst_w || vis_locked;
end

  gw2a_rpll #(
      .FCLKIN("27"),
      .CLKOUTD_SRC("CLKOUTP"),
      .PSDA_SEL(PHASE),
      .IDIV_SEL(GOWIN_RPLL_IDIV),
      .FBDIV_SEL(GOWIN_RPLL_FBDIV),
      .ODIV_SEL(GOWIN_RPLL_ODIV),
      .DYN_SDIV_SEL(GOWIN_RPLL_SDIV)
  ) U_RPLL0 (
      .clockp(clockp),   // 120 MHz
      .clockd(clockd),   // 60 MHz
             .clockd3(clockd3),
      .lock  (vis_locked),
      .clkin (clock_27)
  );

  sync_reset #( .N(3) ) U_VIS_RST1 (
                                    .clock(clockp),
                                    .arst_n(areset_n),
                                    .reset(vis_rst_w));


  // -- Bus Clocks & Reset -- //

  generate if (USE_ULPI_USB) begin : g_use_ulpi_usb

      // Use the 60 MHz (external) onboard USB ULPI PHY as the bus clock.
  reg bus_reset;
  wire usb_clockp, usb_clockd, usb_locked, usb_rst_w;

      // Todo: this should be driven based off of external (ULPI controller) logic
      assign ulpi_rst_n = 1'b1;

      assign bus_clock = usb_clockd;
      assign bus_clk2x = usb_clockp;

always @(posedge bus_clock) begin
    bus_reset <= bus_rst_w || bus_locked;
end

  gw2a_rpll #(
      .FCLKIN("60"),
      .CLKOUTD_SRC("CLKOUTP"),
      .PSDA_SEL(PHASE),
      .IDIV_SEL(GOWIN_RPLL_IDIV),
      .FBDIV_SEL(GOWIN_RPLL_FBDIV),
      .ODIV_SEL(GOWIN_RPLL_ODIV),
      .DYN_SDIV_SEL(GOWIN_RPLL_SDIV)
  ) U_RPLL0 (
      .clockp(usb_clockp),   // 120 MHz
      .clockd(usb_clockd),   // 60 MHz
      .lock  (usb_locked),
      .clkin (ulpi_clock)
  );

  sync_reset #( .N(3) ) U_BUS_RST1 (
                                    .clock(usb_clockd),
                                    .arst_n(areset_n),
                                    .reset(usb_rst_w));

  end else begin : g_no_usb_ulpi

      // If no USB, then default to using the visibilities-clock divided by three.

      assign bus_clock = clockd3;
      assign bus_reset = resetd3;

      // Not used
      assign ulpi_rst_n = 1'b1;

  sync_reset #( .N(3) ) U_BUS_RST1 (
                                    .clock(clockd3),
                                    .arst_n(areset_n),
                                    .reset(resetd3)
);

  end  // g_use_ulpi_usb
  endgenerate


generate if (USE_DDR_SDRAM) begin : g_use_ddr_sdram

wire mem_locked;

  // Todo:
  //  - test these clock settings, as the DDR3 timings are quite fussy ...

`ifdef DDR3_250_MHZ
  // So 27.0 MHz divided by 4, then x37 = 249.75 MHz.
  localparam DDR_FREQ_MHZ = 125;

  localparam IDIV_SEL = 3;
  localparam FBDIV_SEL = 36;
  localparam ODIV_SEL = 4;
  localparam SDIV_SEL = 2;
`else
  // So 27.0 MHz divided by 4, then x29 = 195.75 MHz.
  localparam DDR_FREQ_MHZ = 100;

  localparam IDIV_SEL = 3;
  localparam FBDIV_SEL = 28;
  localparam ODIV_SEL = 4;
  localparam SDIV_SEL = 2;
`endif

  gw2a_rpll #(
      .FCLKIN("27"),
      .IDIV_SEL(IDIV_SEL),
      .FBDIV_SEL(FBDIV_SEL),
      .ODIV_SEL(ODIV_SEL),
      .DYN_SDIV_SEL(SDIV_SEL)
  ) axis_rpll_inst (
      .clkout(mem_clk2x),  // 200 MHz
      .clockd(mem_clock),  // 100 MHz
      .lock  (mem_locked),
      .clkin (clock_27)
  );

    assign mem_reset = ~mem_locked;

end  // g_use_ddr_sdram
endgenerate


endmodule  // clock_reset
