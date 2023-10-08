`timescale 1ns / 100ps
module generic_ddr3_dfi_phy (
    clock,
    reset,

    clk_ddr,

    cfg_valid_i,
    cfg_data_i,

    dfi_cke_i,
    dfi_reset_n_i,
    dfi_cs_n_i,
    dfi_ras_n_i,
    dfi_cas_n_i,
    dfi_we_n_i,
    dfi_odt_i,
    dfi_bank_i,
    dfi_addr_i,
    dfi_wren_i,
    dfi_mask_i,
    dfi_data_i,
    dfi_rden_i,
    dfi_valid_o,
    dfi_data_o,

    ddr3_ck_p_o,
    ddr3_ck_n_o,
    ddr3_cke_o,
    ddr3_reset_n_o,
    ddr3_cs_n_o,
    ddr3_ras_n_o,
    ddr3_cas_n_o,
    ddr3_we_n_o,
    ddr3_odt_o,
    ddr3_ba_o,
    ddr3_a_o,
    ddr3_dm_o,
    ddr3_dqs_p_io,
    ddr3_dqs_n_io,
    ddr3_dq_io
);

  parameter DEFAULT_CL = 6;  // According to JEDEC spec, for DLL=off mode
  parameter DEFAULT_CWL = 6;

  parameter DDR3_WIDTH = 16;
  parameter DDR3_MASKS = DDR3_WIDTH / 8;

  localparam MSB = DDR3_WIDTH - 1;
  localparam QSB = DDR3_MASKS - 1;

  localparam DSB = DDR3_WIDTH + MSB;
  localparam SSB = DDR3_MASKS + QSB;

  parameter ADDR_BITS = 14;
  localparam ASB = ADDR_BITS - 1;

  parameter MAX_RW_LATENCY = 12;  // Maximum 'CL'/'CWL'
  localparam CSB = MAX_RW_LATENCY - 1;


  input clock;
  input reset;

  input clk_ddr;  // Same phase, but twice freq of 'clock'

  input cfg_valid_i;
  input [31:0] cfg_data_i;

  input dfi_cke_i;
  input dfi_reset_n_i;
  input dfi_cs_n_i;
  input dfi_ras_n_i;
  input dfi_cas_n_i;
  input dfi_we_n_i;
  input dfi_odt_i;

  input [2:0] dfi_bank_i;
  input [ASB:0] dfi_addr_i;

  input dfi_wren_i;
  input [SSB:0] dfi_mask_i;
  input [DSB:0] dfi_data_i;

  input dfi_rden_i;
  output dfi_valid_o;
  output [DSB:0] dfi_data_o;

  output ddr3_ck_p_o;
  output ddr3_ck_n_o;
  output ddr3_cke_o;
  output ddr3_reset_n_o;
  output ddr3_cs_n_o;
  output ddr3_ras_n_o;
  output ddr3_cas_n_o;
  output ddr3_we_n_o;
  output ddr3_odt_o;
  output [2:0] ddr3_ba_o;
  output [ASB:0] ddr3_a_o;
  output [QSB:0] ddr3_dm_o;
  inout [QSB:0] ddr3_dqs_p_io;
  inout [QSB:0] ddr3_dqs_n_io;
  inout [MSB:0] ddr3_dq_io;


  reg dq_t, dqs_t;
  reg [QSB:0] dqs_p, dqs_n, dm_q;
  reg [MSB:0] dq_q;
  reg cke_q, reset_n_q, cs_n_q;
  reg ras_n_q, cas_n_q, we_n_q, odt_q;
  reg [  2:0] ba_q;
  reg [ASB:0] addr_q;
  reg [DSB:0] data_q;
  reg [CSB:0] rd_en_q;


  // -- DFI Read-Data Signal Assignments -- //

  assign dfi_valid_o    = rd_en_q[0];
  assign dfi_data_o     = data_q;


  // -- DDR3 Signal Assignments -- //

  assign ddr3_ck_p_o    = ~clock;
  assign ddr3_ck_n_o    = clock;

  assign ddr3_cke_o     = cke_q;
  assign ddr3_reset_n_o = reset_n_q;
  assign ddr3_cs_n_o    = cs_n_q;
  assign ddr3_ras_n_o   = ras_n_q;
  assign ddr3_cas_n_o   = cas_n_q;
  assign ddr3_we_n_o    = we_n_q;
  assign ddr3_odt_o     = odt_q;
  assign ddr3_ba_o      = ba_q;
  assign ddr3_a_o       = addr_q;

  assign ddr3_dqs_p_io  = dqs_t ? {DDR3_MASKS{1'bz}} : dqs_t;
  assign ddr3_dqs_n_io  = dqs_t ? {DDR3_MASKS{1'bz}} : dqs_t;
  assign ddr3_dm_o      = dm_q;
  assign ddr3_dq_io     = dq_t ? dq_q : {DDR3_WIDTH{1'bz}};


  // -- DFI Configuration -- //

  reg [3:0] rd_lat_q, wr_lat_q;

  always @(posedge clock)
    if (reset) begin
      rd_lat_q <= DEFAULT_CL;
    end else if (cfg_valid_i) begin
      rd_lat_q <= cfg_data_i[11:8];
    end

  always @(posedge clock) begin
    if (reset) begin
      wr_lat_q <= DEFAULT_CWL;
    end else if (cfg_valid_i) begin
      wr_lat_q <= cfg_data_i[15:12];  // todo ...
    end
  end


  // -- DDR3 Command Signals -- //

  // todo: polarities of the 'n' signals?
  always @(posedge clock) begin
    if (reset) begin
      cke_q     <= 1'b0;
      reset_n_q <= 1'b0;
      cs_n_q    <= 1'b0;  // todo: 1'b1 ??
      ras_n_q   <= 1'b0;  // todo: 1'b1 ??
      cas_n_q   <= 1'b0;  // todo: 1'b1 ??
      we_n_q    <= 1'b0;  // todo: 1'b1 ??
      ba_q      <= 3'b0;
      addr_q    <= {ADDR_BITS{1'b0}};
      odt_q     <= 1'b0;
    end else begin
      cke_q     <= dfi_cke_i;
      reset_n_q <= dfi_reset_n_i;
      cs_n_q    <= dfi_cs_n_i;
      ras_n_q   <= dfi_ras_n_i;
      cas_n_q   <= dfi_cas_n_i;
      we_n_q    <= dfi_we_n_i;
      odt_q     <= dfi_odt_i;
      ba_q      <= dfi_bank_i;
      addr_q    <= dfi_addr_i;
    end
  end


  // -- DDR3 Data Strobes -- //

  reg [CSB:0] wr_en_q;
  wire [CSB:0] wr_en_w, wr_in_w;
  wire wr_start, wr_stop;

  assign wr_in_w  = dfi_wren_i << wr_lat_q;
  assign wr_en_w  = {1'b0, wr_en_q[CSB:1]} | wr_in_w;
  assign wr_start = wr_en_q[1];
  assign wr_stop  = ~wr_en_q[0];

  always @(posedge clock) begin
    if (reset) begin
      wr_en_q <= {MAX_RW_LATENCY{1'b0}};
    end else begin
      wr_en_q <= wr_en_w;
    end
  end

  always @(posedge clock) begin
    if (reset) begin
      dqs_t <= 1'b1;
    end else if (wr_start) begin
      dqs_t <= 1'b0;
    end else if (wr_stop) begin
      dqs_t <= 1'b1;
    end
  end


  // -- Read Data Valid Signals -- //

  wire [CSB:0] rd_en_w, rd_in_w;

  assign rd_in_w = dfi_rden_i << rd_lat_q;
  assign rd_en_w = {1'b0, rd_en_q[CSB:1]} | rd_in_w;

  always @(posedge clock) begin
    if (reset) begin
      rd_en_q <= {MAX_RW_LATENCY{1'b0}};
    end else begin
      rd_en_q <= rd_en_w;
    end
  end


  // -- Data Capture on Read -- //

  reg [MSB:0] data_l, data_h;

  always @(posedge clock) begin
    data_q <= {data_h, data_l};
  end

  always @(posedge ddr3_dqs_p_io) begin
    if (dqs_t) begin
      data_l <= ddr3_dq_io;
    end
  end

  always @(posedge ddr3_dqs_n_io) begin
    if (dqs_t) begin
      data_h <= ddr3_dq_io;
    end
  end


endmodule  // generic_ddr3_dfi_phy
