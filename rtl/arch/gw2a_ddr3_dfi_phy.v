`timescale 1ns / 100ps
/**
 * DDR3 PHY for GoWin GW2A FPGA's, and using the DDR3 PHY Interface (DFI).
 */
module gw2a_ddr3_dfi_phy (  /*AUTOARG*/);

  parameter DQ_IN_DELAY_INIT = 64;

  parameter TPHY_RDLAT = 4;
  parameter TPHY_WRLAT = 3;
  parameter TPHY_WRDATA = 0;

  parameter DDR3_WIDTH = 16;
  parameter DDR3_MASKS = DDR3_WIDTH / 8;

  localparam MSB = DDR3_WIDTH - 1;
  localparam QSB = DDR3_MASKS - 1;

  localparam DSB = DDR3_WIDTH + MSB;
  localparam SSB = DDR3_MASKS + QSB;

  parameter ADDR_BITS = 14;
  localparam ASB = ADDR_BITS - 1;

parameter MAX_RW_LATENCY = 12; // Maximum 'CL'/'CWL'
localparam CSB = MAX_RW_LATENCY - 1;


  input clock; // Global (bus) clock, 100 MHz
  input reset; // Global, synchronous reset

  input clk_ddr_ref;  // DDR 200 MHz clock
  input clk_ddr_270;  // 270 degree phase-shifted DDR clock

  input cfg_valid_i;
  input [31:0] cfg_i;

  input [ASB:0] dfi_address_i;
  input [2:0] dfi_bank_i;
  input dfi_cas_n_i;
  input dfi_cke_i;
  input dfi_cs_n_i;
  input dfi_odt_i;
  input dfi_ras_n_i;
  input dfi_reset_n_i;
  input dfi_we_n_i;
  input [DSB:0] dfi_wrdata_i;
  input dfi_wrdata_en_i;
  input [SSB:0] dfi_wrdata_mask_i;
  input dfi_rddata_en_i;
  output [DSB:0] dfi_rddata_o;
  output dfi_rddata_valid_o;
  output [1:0] dfi_rddata_dnv_o;

  output ddr3_ck_p_o;
  output ddr3_ck_n_o;
  output ddr3_cke_o;
  output ddr3_reset_n_o;
  output ddr3_ras_n_o;
  output ddr3_cas_n_o;
  output ddr3_we_n_o;
  output ddr3_cs_n_o;
  output [2:0] ddr3_ba_o;
  output [ASB:0] ddr3_addr_o;
  output ddr3_odt_o;
  output [QSB:0] ddr3_dm_o;
  inout [QSB:0] ddr3_dqs_p_io;
  inout [QSB:0] ddr3_dqs_n_io;
  inout [MSB:0] ddr3_dq_io;


  //-----------------------------------------------------------------
  // Configuration
  //-----------------------------------------------------------------
  `define DDR_PHY_CFG_RDLAT_R 11:8

  reg [3:0] rd_lat_q;

  always @(posedge clock)
    if (reset) begin
      rd_lat_q <= TPHY_RDLAT;
    end else if (cfg_valid_i) begin
      rd_lat_q <= cfg_i[`DDR_PHY_CFG_RDLAT_R];
    end


  //-----------------------------------------------------------------
  // DDR Clock
  //-----------------------------------------------------------------
  // ddr3_ck_p_o = ~clock
  TLVDS_OBUF
( .I(~clock),
  .O(ddr3_ck_p_o),
  .OB(ddr3_ck_n_o)
  );


  //-----------------------------------------------------------------
  // Command
  //-----------------------------------------------------------------
  // synthesis attribute IOB of cke_q is "TRUE"
  // synthesis attribute IOB of reset_n_q is "TRUE"
  // synthesis attribute IOB of ras_n_q is "TRUE"
  // synthesis attribute IOB of cas_n_q is "TRUE"
  // synthesis attribute IOB of we_n_q is "TRUE"
  // synthesis attribute IOB of cs_n_q is "TRUE"
  // synthesis attribute IOB of ba_q is "TRUE"
  // synthesis attribute IOB of addr_q is "TRUE"
  // synthesis attribute IOB of odt_q is "TRUE"

  reg cke_q, reset_n_q, cs_n_q;
  reg ras_n_q, cas_n_q, we_n_q, odt_q;
  reg [  2:0] ba_q;
  reg [ASB:0] addr_q;

`ifndef __mental
// Assuming that the registers have been placed in IOB's ...
assign ddr3_cke_o     = cke_q;
assign ddr3_reset_n_o = reset_n_q;
assign ddr3_cs_n_o    = cs_n_q;
assign ddr3_ras_n_o   = ras_n_q;
assign ddr3_cas_n_o   = cas_n_q;
assign ddr3_we_n_o    = we_n_q;
assign ddr3_odt_o     = odt_q;
assign ddr3_ba_o      = ba_q;
assign ddr3_addr_o    = addr_q;

  // todo: polarities of the 'n' signals?
  always @(posedge clock) begin
    if (reset) begin
      cke_q     <= 1'b0;
      reset_n_q <= 1'b0;
      cs_n_q    <= 1'b0; // todo: 1'b1 ??
      ras_n_q   <= 1'b0; // todo: 1'b1 ??
      cas_n_q   <= 1'b0; // todo: 1'b1 ??
      we_n_q    <= 1'b0; // todo: 1'b1 ??
      ba_q      <= 3'b0;
      addr_q    <= 15'b0;
      odt_q     <= 1'b0;
    end else begin
      cke_q     <= dfi_cke_i;
      reset_n_q <= dfi_reset_n_i;
      cs_n_q    <= dfi_cs_n_i;
      ras_n_q   <= dfi_ras_n_i;
      cas_n_q   <= dfi_cas_n_i;
      we_n_q    <= dfi_we_n_i;
      ba_q      <= dfi_bank_i;
      addr_q    <= dfi_address_i;
      odt_q     <= dfi_odt_i;
    end
  end

`else /* __mental */
//
// Output via ODDR primitives
//
wire [24:0] ddr3_control_signals_q = {addr_q, ba_q, odt_q, we_n_q, cas_n_q, ras_n_q, cs_n_q, reset_n_q, cke_q};
wire [24:0] ddr3_control_signals_w;

assign ddr3_cke_o     = ddr3_control_signals_w[0];
assign ddr3_reset_n_o = ddr3_control_signals_w[1];
assign ddr3_cs_n_o    = ddr3_control_signals_w[2];
assign ddr3_ras_n_o = ddr3_control_signals_w[3];
assign ddr3_cas_n_o = ddr3_control_signals_w[4];
assign ddr3_we_n_o = ddr3_control_signals_w[5];
assign ddr3_odt_o = ddr3_control_signals_w[6];
assign ddr3_ba_o = ddr3_control_signals_w[9:7];
assign ddr3_addr_o = ddr3_control_signals_w[24:10];


gw2a_oddr_tbuf
#( .STATIC_DELAY(7'h00),
   .INIT(1'b0)
   ) ddr3_control_iob_inst [24:0]
( .clock(clock),

  .dynamic_delay_i(1'b0),
  .adjust_reverse_i(1'b0),
  .adjust_step_i(1'b0),
  .delay_overflow_o(),

  .d0_i(ddr3_control_signals_q),
  .d1_i(ddr3_control_signals_q),
  .t_ni(1'b0),
  .q_o(ddr3_control_signals_w)
  );

/*
gw2a_oddr_tbuf
#( .STATIC_DELAY(7'h00),
   .INIT(1'b0)
   ) cke_iob_inst
( .clock(clock),

  .dynamic_delay_i(1'b0),
  .adjust_reverse_i(1'b0),
  .adjust_step_i(1'b0),
  .delay_overflow_o(),

  .d0_i(dfi_cke_i),
  .d1_i(dfi_cke_i),
  .t_ni(1'b0),
  .q_o(ddr3_cke_o)
  );
*/
`endif


  //-----------------------------------------------------------------
  // DQS Output Enable & I/O Buffers
  //-----------------------------------------------------------------

  reg dqs_out_en_n_q;
  reg [CSB:0] wr_en_q;
  wire [CSB:0] wr_en_w;

  assign wr_en_w = {1'b0, wr_en_q[CSB:1]} | (dfi_wrdata_en_i << wr_lat_q);
  assign wr_start = wr_en_q[1];
  assign wr_stop = ~wr_en_q[0];

  always @(posedge clock) begin
    if (reset) begin
      wr_en_q <= {MAX_RW_LATENCY{1'b0}};
    end else begin
      wr_en_q <= wr_en_w;
    end
  end

  always @(posedge clock) begin
    if (reset) begin
      dqs_out_en_n_q <= 1'b1;
    end else if (wr_start) begin
      dqs_out_en_n_q <= 1'b0;
    end else if (wr_stop) begin
      dqs_out_en_n_q <= 1'b1;
    end
  end


  // -- Data Strobe Signals -- //

wire [QSB:0] ddr3_dqs_p_i0, ddr3_dqs_p_i1;
wire [QSB:0] ddr3_dqs_n_i0, ddr3_dqs_n_i1;
wire [QSB:0] dqs_w;

TLVDS_IOBUF dqs_iob_inst [QSB:0]
( .I  (clk_ddr_270),
  .OEN(dqs_out_en_n_q),
  .O  (dqs_w),
  .IOB(ddr3_dqs_n_io),
  .IO (ddr3_dqs_p_io)
  );

IDDR
  #(.Q0_INIT(1'b1),
    .Q1_INIT(1'b1)
) dqs_p_iddr_inst [QSB:0]
  ( .CLK(clock),
    .D  (ddr3_dqs_p_io),
    .Q0 (ddr3_dqs_p_i0), // these two outputs should be identical
    .Q1 (ddr3_dqs_p_i1)
    );

IDDR
  #(.Q0_INIT(1'b1),
    .Q1_INIT(1'b1)
) dqs_n_iddr_inst [QSB:0]
  ( .CLK(clock),
    .D  (ddr3_dqs_n_io),
    .Q0 (ddr3_dqs_n_i0), // these two outputs should be identical
    .Q1 (ddr3_dqs_n_i1)
    );


  //-----------------------------------------------------------------
  // Write Data (DQ)
  //-----------------------------------------------------------------
  reg [DSB:0] dfi_wrdata_q;

  always @(posedge clock) begin
    if (reset) begin
      dfi_wrdata_q <= 32'b0;
    end else begin
      dfi_wrdata_q <= dfi_wrdata_i;
    end
  end


  wire [MSB:0] dq_in_w;
  wire [MSB:0] dq_out_w;
  wire [MSB:0] dq_out_en_n_w;

  OSER4_MEM qs_oser4_mem_inst[MSB:0] ();

  IODELAY dq_iodelay_inst[MSB:0] ();


  //-----------------------------------------------------------------
  // Data Mask (DM)
  //-----------------------------------------------------------------
  wire [  1:0] dm_out_w;
  reg  [SSB:0] dfi_wr_mask_q;

  assign ddr3_dm_o = dm_out_w;

reg [QSB:0] dm_lo_r, dm_hi_r;

always @(posedge clk_ddr_ref) begin
  {dm_hi_r, dm_lo_r, dm_wait} <= {dm_lo_r, salad};
end

  always @(posedge clock) begin
    if (reset) begin
      dfi_wr_mask_q <= 4'b0;
    end else begin
      dfi_wr_mask_q <= dfi_wrdata_mask_i;
    end
  end

ODDR dm_iob_inst [QSB:0]
( .CLK(~clk_ddr_ref),
  .TX(dqs_out_en_n_q),
  .D0(dm_lo_w),
  .D1(dm_hi_w),
  .Q0(ddr3_dm_o),
  .Q1(ddr3_dm_t)
  );


  OSER4_MEM dm_inst [QSB:0] ();

  IODELAY dm_delay_inst [QSB:0] ();


  //-----------------------------------------------------------------
  // Read capture
  //-----------------------------------------------------------------
  wire [DSB:0] rd_data_w;
  wire [MSB:0] dq_in_delayed_w;

  assign dfi_rddata_o     = rd_data_w;
  assign dfi_rddata_dnv_o = 2'b0;

// If DDR is correctly set up, then all of these should be the same
wire [MSB:0] dq_i0, dq_i1, dq_i2, dq_i3;

IDES4
#( .GSREN("false"),
   .LSREN("true")
 ) dq_iob_inst [MSB:0]
 ( .FCLK(clk_270), // 200 MHz, 270 degree phase-shifted
   .PCLK(clock), // 100 MHz
   .RESET(reset),
   .CALIB(calib),
   .D (dq_io),
   .Q0(dq_i0),
   .Q1(dq_i1),
   .Q2(dq_i2),
   .Q3(dq_i3)
 );


  //-----------------------------------------------------------------
  // Read Valid
  //-----------------------------------------------------------------
  reg [CSB:0] rd_en_q;
  wire [CSB:0] rd_en_w;

  assign rd_en_w = {1'b0, rd_en_q[CSB:1]} | (dfi_rddata_en_i << rd_lat_q);
  assign dfi_rddata_valid_o = rd_en_q[0];

`ifndef __mental
  always @(posedge clock) begin
    if (reset) begin
      rd_en_q <= {MAX_RW_LATENCY{1'b0}};
    end else begin
      rd_en_q <= rd_en_w;
    end
  end
`else
  reg [CSB:0] rd_en_r;

  always @* begin
    rd_en_r = {1'b0, rd_en_q[CSB:1]};
    rd_en_r[rd_lat_q] = dfi_rddata_en_i;
  end

  always @(posedge clock) begin
    if (reset) begin
      rd_en_q <= {MAX_RW_LATENCY{1'b0}};
    end else begin
      rd_en_q <= rd_en_r;
    end
  end
`endif


endmodule  // gw2a_ddr3_dfi_phy
