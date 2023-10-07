`timescale 1ns / 100ps
/**
 * Copyright (C) 2023, Patrick Suggate.
 *
 * DMA core for a DDR3 SDRAM controller, using an AXI4-Lite interface for DMA
 * configuration (i.e., for setting the read- & write- starting addresses), and
 * AXI4-Stream for the SDRAM read/write data to/from the attached core.
 * 
 * Complete frames indicated via 's_tlast'/'m_tlast', and DDR3 SDRAM commands
 * are generated as required.
 * 
 * Note: the read and write FIFO's must be large enough to store an entire frame
 * of data.
 * 
 */
module axil_ddr3_dma (  /*AUTOARG*/);

  parameter AXIL_WIDTH = 32;
  localparam AXIL_STRBS = DATA_WIDTH / 8;
  localparam MSB = DATA_WIDTH - 1;
  localparam SSB = DATA_STRBS - 1;

  parameter AXIL_ADDRS = 4;
  localparam ASB = ADDR_WIDTH - 1;

  parameter AXIS_WIDTH = 8;
  localparam XSB = AXIS_WIDTH - 1;


  input axi_clock;
  input axi_reset;

  // -- AXI4-Lite Controller Write & Read Channel -- //

  input aw_valid;
  output aw_ready;
  input [2:0] aw_prot;  // note: ignored
  input [ASB:0] aw_addr;

  input wr_valid;
  output wr_ready;
  input [SSB:0] wr_strb;
  input [MSB:0] wr_data;

  output wb_valid;
  input wb_ready;
  output wb_resp;

  input ar_valid;
  output ar_ready;
  input [2:0] ar_prot;  // note: ignored
  input [ASB:0] ar_addr;

  output rd_valid;
  input rd_ready;
  output rd_resp;
  output [MSB:0] rd_data;

  // -- AXI4-Stream Data Write & Read Channels -- //

  input s_tvalid;
  output s_tready;
  input s_tlast;
  input [XSB:0] s_tdata;

  output m_tvalid;
  input m_tready;
  output m_tlast;
  output [XSB:0] m_tdata;



endmodule  // axil_ddr3_dma
