`timescale 1ns / 100ps
/**
 * Converts AXI4 requests into simple memory-controller commands.
 * 
 * Notes:
 *  - assumes that the AXI4 interface converts write-data into 128-bit chunks,
 *    padding as required;
 *  - read data will also be a (continuous) stream of 128-bit chunks, so the
 *    AXI4 interface will have to drop any (unwanted) trailing data, if not
 *    required;
 *  - assumes that the memory controller and the AXI4 bus are within the same
 *    clock-domain;
 * 
 * Copyright 2023, Patrick Suggate.
 * 
 */
module ddr3_axi_ctrl (  /*AUTOARG*/);

  parameter DDR_FREQ_MHZ = 100;
  parameter DDR_WR_LATENCY = 6;
  parameter DDR_RD_LATENCY = 5;
  localparam DDR_BURST_LEN = 4;

  localparam DDR_BANK_BITS = 3;
  localparam BSB = DDR_BANK_BITS - 1;
  parameter DDR_COL_BITS = 9;
  localparam CSB = DDR_COL_BITS - 1;
  parameter DDR_ROW_BITS = 15;
  localparam RSB = DDR_ROW_BITS - 1;

  parameter WIDTH = 32;
  localparam MSB = WIDTH - 1;

  parameter MASKS = DDR_DATA_WIDTH / 8;
  localparam SSB = MASKS - 1;


  input clock;
  input reset;

  input axi_awvalid_i;  // AXI4 Write Address Port
  output axi_awready_o;
  input [MSB:0] axi_awaddr_i;
  input [3:0] axi_awid_i;
  input [7:0] axi_awlen_i;
  input [1:0] axi_awburst_i;
  input axi_wvalid_i;  // AXI4 Write Data Port
  output axi_wready_o;
  input [MSB:0] axi_wdata_i;
  input [3:0] axi_wstrb_i;
  input axi_wlast_i;
  output axi_bvalid_o;  // AXI4 Write Response
  input axi_bready_i;
  output [1:0] axi_bresp_o;
  output [3:0] axi_bid_o;
  input axi_arvalid_i;  // AXI4 Read Address Port
  output axi_arready_o;
  input [MSB:0] axi_araddr_i;
  input [3:0] axi_arid_i;
  input [7:0] axi_arlen_i;
  input [1:0] axi_arburst_i;
  input axi_rready_i;  // AXI4 Read Data Port
  output axi_rvalid_o;
  output [MSB:0] axi_rdata_o;
  output [1:0] axi_rresp_o;
  output [3:0] axi_rid_o;
  output axi_rlast_o;

  output ram_wren_o;
  output ram_rden_o;
  input ram_accept_i;
  input ram_valid_i;
  input ram_error_i;
  input [3:0] ram_resp_id_i;
  output [3:0] ram_req_id_o;
  output [MSB:0] ram_addr_o;
  output [SSB:0] ram_wrmask_o;
  output [MSB:0] ram_wrdata_o;
  input [MSB:0] ram_rddata_i;


  // -- Turn AXI4 Commands into Memory-Controller Commands -- //

  // todo: this is but a sketch ...
  localparam COMMAND_WIDTH = 4 + 1 + WIDTH;


  // -- Queue the Commands to the Memory-Controller -- //

  wire cmd_valid, cmd_queued, ram_accept_w;
  reg  [COMMAND_WIDTH-1:0] command_q;
  wire [COMMAND_WIDTH-1:0] command_w, command_a;

  assign command_w = {req_id, req_we, req_ad};
  assign cmd_valid = (ram_wren_o || ram_rden_o) && ram_accept_i;

  assign ram_req_id_o = command_a[COMMAND_WIDTH-1:COMMAND_WIDTH-3];

  always @(posedge clock) begin
    command_q <= command_w;
  end

  sync_fifo #(
      .WIDTH (COMMAND_WIDTH),
      .ABITS (4),
      .OUTREG(0)
  ) command_fifo_inst (
      .clock(clock),
      .reset(reset),

      .valid_i(cmd_valid),
      .ready_o(cmd_queued),
      .data_i (command_q),

      .valid_o(),
      .ready_i(ram_accept_w),
      .data_o (command_a)
  );


  // -- Synchronous, 2 kB, Write-Data and Read-Data FIFO's -- //

  wire ram_wren_w, ram_accept, ram_ready;

  sync_fifo #(
      .WIDTH (MASKS + WIDTH),
      .ABITS (9),
      .OUTREG(0)
  ) wrdata_fifo_inst (
      .clock(clock),
      .reset(reset),

      .valid_i(axi_wvalid_i),
      .ready_o(axi_wready_o),
      .data_i ({axi_wstrb_i, axi_wdata_i}), // todo: pad end of bursts

      .valid_o(ram_wren_w),
      .ready_i(ram_accept),
      .data_o ({ram_wrmask_o, ram_wrdata_o})
  );

  sync_fifo #(
      .WIDTH (WIDTH),
      .ABITS (9),
      .OUTREG(0)
  ) rddata_fifo_inst (
      .clock(clock),
      .reset(reset),

      .valid_i(ram_valid_i),
      .ready_o(ram_ready),
      .data_i (ram_rddata_i), // todo: pad end of bursts

      .valid_o(axi_rvalid_o),
      .ready_i(axi_rready_i),
      .data_o (axi_rdata_o)
  );


endmodule  // ddr3_axi_ctrl
