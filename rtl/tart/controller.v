`timescale 1ns / 100ps
/*
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
 *
 */
module controller #(
    parameter  integer WIDTH = 8,
    localparam integer MSB   = WIDTH - 1,
    localparam integer ABITS = 2,
    localparam integer ASB   = ABITS - 1,
    localparam integer STRBS = WIDTH / 8,
    localparam integer SSB   = STRBS - 1
) (
    input clock,
    input reset,

    input axil_awvalid_i,
    output axil_awready_o,
    input [ASB:0] axil_awaddr_i,

    input axil_wvalid_i,
    output axil_wready_o,
    input [SSB:0] axil_wstrb_i,
    input [MSB:0] axil_wdata_i,

    output axil_bvalid_o,
    input axil_bready_i,
    output [1:0] axil_bresp_o,

    input axil_arvalid_i,
    output axil_arready_o,
    input [ASB:0] axil_araddr_i,

    output axil_rvalid_o,
    input axil_rready_i,
    output [1:0] axil_rresp_o,
    output [MSB:0] axil_rdata_o,

    output tart_reset_o,
    output capture_en_o,
    output acquire_en_o,
    output correlator_o,
    input  visibility_i
);


  // -- Signals & State Registers -- //

  reg rst_q, cap_q, acq_q, cor_q;

  always @(posedge clock) begin
    if (reset) begin
      rst_q <= 1'b1;
      cap_q <= 1'b0;
      acq_q <= 1'b0;
      cor_q <= 1'b0;
    end else begin
      rst_q <= 1'b0;  // todo ...
    end
  end


endmodule  // controller
