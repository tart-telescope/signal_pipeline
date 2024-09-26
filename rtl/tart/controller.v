`timescale 1ns / 100ps
/**
 * Module      : verilog/tart_control.v
 * Copyright   : (C) Tim Molteno     2023
 *             : (C) Max Scheel      2023
 *             : (C) Patrick Suggate 2023
 * License     : MIT
 *
 * Maintainer  : Patrick Suggate <patrick.suggate@gmail.com>
 * Stability   : Experimental
 * Portability : only tested with a Papilio board (Xilinx Spartan VI)
 *
 *
 * This file is part of TART.
 *
 * Description:
 * TART's control registers module, connected via AXI4-Lite interconnect.
 *
 * Has system registers for:
 *   2'b00  --  status register;
 *   2'b01  --  extra status-flags;
 *   2'b10  --  reserved/miscellaneous register; and
 *   2'b11  --  reset register,
 *
 * and these each have the bit-fields show below.
 *
 *
 * REGISTERS:
 *  Reg#   7          6          5        4       3      2    1    0
 *      -------------------------------------------------------------------
 *   00 ||  VIZ_EN  | PENDING  | CAP_EN | DEBUG | AQ_EN |    AQ_STATE    ||
 *      ||   (RO)   |   (RO)   |  (RO)  | (RO)  | (RO)  |      (RO)      ||
 *      -------------------------------------------------------------------
 *   01 || OVERFLOW | UNDERRUN |              5'h00              | BUSY  ||
 *      ||   (RO)   |   (RO)   |                                 | (RO)  ||
 *      -------------------------------------------------------------------
 *   10 ||                           RESERVED                            ||
 *      ||                                                               ||
 *      -------------------------------------------------------------------
 *   11 ||                          7'h00                        | RESET ||
 *      ||                                                       | (R/W) ||
 *      -------------------------------------------------------------------
 *
 * By default, the DSP/visibilities unit has address 7'b100_00xx.
 *
 * Note:
 *  - based on `tart_control.v`, from TART2;
 *  - Tang Primer Core Board has a 27.0 MHz oscillator;
 *  - TART motherboard has a 16.368 MHz oscillator;
 *  - Run the correlators at 12x 16.368 MHz (same as TART2)?
 *  - Raspberry Pi 4 has SPI bus with the following clocks:
 *     + 250 MHz / 'n';
 *     + 'n' is any even integer from 2 to 65536;
 *  - The DDR3 SDRAM should have a clock-rate between 100-125 MHz;
 *  - The hardware testbench board has a USB2.0 ULPI PHY with a 60 MHz output
 *    oscillator;
 *
 */
module controller #(
    parameter  integer WIDTH = 48,
    localparam integer MSB   = WIDTH - 1,
    localparam integer ABITS = 2,
    localparam integer ASB   = ABITS - 1,
    localparam integer STRBS = WIDTH / 8,
    localparam integer SSB   = STRBS - 1
) (
    input areset_n,  // Default: button 'S2' on Tang 2k Primer dev-board
    input clock_in,  // Default: 16.368 MHz on TART, or 27.0 MHz on dev-board

    output sig_clk_o,
    output sig_rst_o,

    // Set/cleared via USB commands //
    output tart_reset_o,
    output capture_en_o,
    output acquire_en_o,
    output correlator_o,
    input  visibility_i,

    input ddr3_ready_i,

    // USB clock domain signals
    input bus_clock,  // Default: 60.0 MHz
    input bus_reset,

    // From USB
    input s_tvalid,
    output s_tready,
    input s_tlast,
    input [7:0] s_tdata,

    // From correlator
    input v_tvalid,
    output v_tready,
    input [SSB:0] v_tkeep,
    input v_tlast,
    input [MSB:0] v_tdata,

    // To USB
    output m_tvalid,
    input m_tready,
    output m_tkeep,
    output m_tlast,
    output [7:0] m_tdata
);

  //
  // Todo:
  //  - MMIO interface to TART top-level control module ??
  //  - better plumbing to DDR3 controller;
  //

  // -- Signals & State Registers -- //

  reg cap_q, acq_q;
  wire clock, reset;

  // -- I/O Assignments -- //

  assign sig_clk_o = clock_in;

  assign tart_reset_o = sig_rst_o;
  assign capture_en_o = cap_q;
  assign acquire_en_o = acq_q;
  assign correlator_o = acq_q;

  assign m_tvalid = v_tvalid;
  assign v_tready = m_tready;
  assign m_tkeep = v_tkeep;
  assign m_tlast = v_tlast;
  assign m_tdata = v_tdata;

  // -- Reset Logic -- //

  assign clock = bus_clock;
  assign reset = bus_reset;

  // Synchronous reset (active 'LO') for the acquisition unit.
  sync_reset #(
      .N(2)
  ) U_SIGRST (
      .clock(sig_clk_o),  // Default: 16.368 MHz
      .arstn(aresetn),
      .reset(sig_rst_o)
  );

  // -- Correlator Start/Run/Stop -- //

  reg dx1_q, dx0_q;

  always @(posedge sig_clk_o) begin
    if (sig_rst_o) begin
      cap_q <= 1'b0;
      acq_q <= 1'b0;
    end else begin
      cap_q <= 1'b1;

      // Todo: currently auto-starts when the DDR3 is ready to receive raw
      //   data.
      {acq_q, dx1_q, dx0_q} <= {dx1_q, dx0_q, ddr3_ready_i};
    end
  end


endmodule  /* controller */
