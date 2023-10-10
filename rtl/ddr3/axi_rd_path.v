`timescale 1ns / 100ps
module axi_rd_path (
    clock,
    reset,

    axi_arvalid_i,
    axi_arready_o,
    axi_araddr_i,
    axi_arid_i,
    axi_arlen_i,
    axi_arburst_i,

    axi_rready_i,
    axi_rvalid_o,
    axi_rlast_o,
    axi_rresp_o,
    axi_rid_o,
    axi_rdata_o,

    mem_fetch_o,
    mem_accept_i,
    mem_rdid_o,
    mem_addr_o,
    mem_valid_i,
    mem_ready_o,
    mem_last_i,
    mem_rdid_i,
    mem_data_i
);

  parameter ADDRS = 32;
  localparam ASB = ADDRS - 1;

  parameter WIDTH = 32;
  localparam MSB = WIDTH - 1;

  parameter MASKS = WIDTH / 8;
  localparam SSB = MASKS - 1;

  parameter AXI_ID_WIDTH = 4;
  localparam ISB = AXI_ID_WIDTH - 1;

  parameter CTRL_FIFO_DEPTH = 16;
  parameter CTRL_FIFO_BLOCK = 0;
  localparam CBITS = $clog2(CTRL_FIFO_DEPTH);

  parameter DATA_FIFO_DEPTH = 512;
  parameter DATA_FIFO_BLOCK = 1;
  localparam DBITS = $clog2(DATA_FIFO_DEPTH);


  input clock;
  input reset;

  input axi_arvalid_i;  // AXI4 Read Address Port
  output axi_arready_o;
  input [ISB:0] axi_arid_i;
  input [7:0] axi_arlen_i;
  input [1:0] axi_arburst_i;
  input [ASB:0] axi_araddr_i;

  input axi_rready_i;  // AXI4 Read Data Port
  output axi_rvalid_o;
  output [MSB:0] axi_rdata_o;
  output [1:0] axi_rresp_o;
  output [ISB:0] axi_rid_o;
  output axi_rlast_o;

  output mem_fetch_o;
  input mem_accept_i;
  output [ISB:0] mem_rdid_o;
  output [ASB:0] mem_addr_o;

  input mem_valid_i;
  output mem_ready_o;
  input mem_last_i;
  input [ISB:0] mem_rdid_i;
  input [MSB:0] mem_data_i;


  // -- Constants -- //

  localparam [1:0] BURST_INCR = 2'b01;


`ifdef __icarus
  always @(posedge clock) begin
    if (reset);
    else begin
      if (axi_arvalid_i && axi_arburst_i != BURST_INCR) begin
        $error("%10t: Only 'INCR' READ bursts are supported", $time);
        $fatal;
      end
    end
  end
`endif


  reg aready = 1'b0;

  assign mem_fetch_o = aready;


  // -- Chunk-up Large Read-Data Bursts -- //


  // -- Read-Data Command FIFO -- //

  localparam COMMAND_WIDTH = ADDRS + AXI_ID_WIDTH;

  wire cmd_valid = axi_arvalid_i & aready;
  wire cmd_ready;

  sync_fifo #(
      .WIDTH (COMMAND_WIDTH),
      .ABITS (CBITS),
      .OUTREG(CTRL_FIFO_BLOCK)
  ) command_fifo_inst (
      .clock(clock),
      .reset(reset),

      .valid_i(cmd_valid),
      .ready_o(cmd_ready),
      .data_i ({axi_araddr_i, axi_arid_i}),

      .valid_o(),
      .ready_i(mem_accept_w),
      .data_o ({mem_addr_o, mem_rdid_o})
  );


  // -- Synchronous, 2 kB, Read-Data FIFO -- //

  sync_fifo #(
      .WIDTH (WIDTH + 1),
      .ABITS (DBITS),
      .OUTREG(DATA_FIFO_BLOCK)
  ) rddata_fifo_inst (
      .clock(clock),
      .reset(reset),

      .valid_i(mem_valid_i),
      .ready_o(mem_ready_o),
      .data_i ({mem_last_i, mem_data_i}), // todo: pad end of bursts

      .valid_o(axi_rvalid_o),
      .ready_i(axi_rready_i),
      .data_o ({axi_rlast_o, axi_rdata_o})
  );


endmodule  // axi_rd_path
