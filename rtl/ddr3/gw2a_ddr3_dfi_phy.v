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


  input clock;
  input clk_ddr_i;  // 90 degree phase shifted version of clock
  input reset;

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
  ODDRC u_pad_ck (
        .CLK(clock)
      , .CLEAR(reset)
      , .TX(1'b1)
      , .D0(0)
      , .D1(1)
      , .Q0(ddr3_ck_p_o)
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

  assign ddr3_cke_o     = cke_q;
  assign ddr3_reset_n_o = reset_n_q;
  assign ddr3_cs_n_o    = cs_n_q;
  assign ddr3_ras_n_o   = ras_n_q;
  assign ddr3_cas_n_o   = cas_n_q;
  assign ddr3_we_n_o    = we_n_q;
  assign ddr3_ba_o      = ba_q;
  assign ddr3_addr_o    = addr_q;
  assign ddr3_odt_o     = odt_q;

  // todo: polarities of the 'n' signals?
  always @(posedge clock) begin
    if (reset) begin
      cke_q     <= 1'b0;
      reset_n_q <= 1'b0;
      cs_n_q    <= 1'b0;
      ras_n_q   <= 1'b0;
      cas_n_q   <= 1'b0;
      we_n_q    <= 1'b0;
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

  OSER4 cke_oser4_inst ();
  OSER4 reset_n_oser4_inst ();
  OSER4 cs_n_oser4_inst ();
  OSER4 ras_oser4_inst ();
  OSER4 cas_oser4_inst ();
  OSER4 we_oser4_inst ();
  OSER4 odt_oser4_inst ();

  IODELAY cke_iodelay_inst ();
  IODELAY reset_n_iodelay_inst ();
  IODELAY cs_n_iodelay_inst ();
  IODELAY ras_iodelay_inst ();
  IODELAY cas_iodelay_inst ();
  IODELAY we_iodelay_inst ();
  IODELAY odt_iodelay_inst ();

  OSER4 ba_oser4_inst[2:0] ();
  OSER4 ad_oser4_inst[14:0] ();

  IODELAY ba_iodelay_inst[2:0] ();
  IODELAY ad_iodelay_inst[14:0] ();


  //-----------------------------------------------------------------
  // Write Output Enable
  //-----------------------------------------------------------------
  reg wr_valid_q0, wr_valid_q1, wr_valid_q2;
  reg dqs_out_en_n_q;

  always @(posedge clock)
    if (reset) begin
      wr_valid_q0 <= 1'b0;
      wr_valid_q1 <= 1'b0;
      wr_valid_q2 <= 1'b0;
    end else begin
      wr_valid_q0 <= dfi_wrdata_en_i;
      wr_valid_q1 <= wr_valid_q0;
      wr_valid_q2 <= wr_valid_q1;
    end

  always @(posedge clock) begin
    if (reset) begin
      dqs_out_en_n_q <= 1'b1;
    end else if (wr_valid_q1) begin
      dqs_out_en_n_q <= 1'b0;
    end else if (!wr_valid_q2) begin
      dqs_out_en_n_q <= 1'b1;
    end
  end


  //-----------------------------------------------------------------
  // DQS I/O Buffers
  //-----------------------------------------------------------------
  wire [1:0] dqs_out_en_n_w = {dqs_out_en_n_q, dqs_out_en_n_q};
  wire [1:0] dqs_out_w;
  wire [1:0] dqs_in_w;


  //-----------------------------------------------------------------
  // Write Data Strobe (DQS)
  //-----------------------------------------------------------------

  // 90 degrees delayed version of clock
  assign dqs_out_w[0] = clk_ddr_i;
  assign dqs_out_w[1] = clk_ddr_i;


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

  always @(posedge clock) begin
    if (reset) begin
      dfi_wr_mask_q <= 4'b0;
    end else begin
      dfi_wr_mask_q <= dfi_wrdata_mask_i;
    end
  end

  OSER4_MEM dm_inst0 ();
  OSER4_MEM dm_inst1 ();

  IODELAY dm_delay_inst0 ();
  IODELAY dm_delay_inst1 ();


  //-----------------------------------------------------------------
  // Read capture
  //-----------------------------------------------------------------
  wire [DSB:0] rd_data_w;
  wire [MSB:0] dq_in_delayed_w;

  assign dfi_rddata_o     = rd_data_w;
  assign dfi_rddata_dnv_o = 2'b0;

  IDES4_MEM dqi_inst[MSB:0] ();


  //-----------------------------------------------------------------
  // Read Valid
  //-----------------------------------------------------------------
  localparam RD_SHIFT_W = 12;

  reg [RD_SHIFT_W-1:0] rd_en_q;
  reg [RD_SHIFT_W-1:0] rd_en_r;

  always @* begin
    rd_en_r = {1'b0, rd_en_q[RD_SHIFT_W-1:1]};
    rd_en_r[rd_lat_q] = dfi_rddata_en_i;
  end

  always @(posedge clock)
    if (reset) rd_en_q <= {(RD_SHIFT_W) {1'b0}};
    else rd_en_q <= rd_en_r;

  assign dfi_rddata_valid_o = rd_en_q[0];


endmodule  // gw2a_ddr3_dfi_phy
