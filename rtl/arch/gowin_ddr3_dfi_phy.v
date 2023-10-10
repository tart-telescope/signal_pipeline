`timescale 1ns / 100ps
module gowin_ddr3_dfi_phy (
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

  parameter DDR3_WIDTH = 16;
  parameter DDR3_MASKS = DDR3_WIDTH / 8;

  localparam MSB = DDR3_WIDTH - 1;
  localparam QSB = DDR3_MASKS - 1;

  localparam DSB = DDR3_WIDTH + MSB;
  localparam SSB = DDR3_MASKS + QSB;

  parameter ADDR_BITS = 14;
  localparam ASB = ADDR_BITS - 1;

  parameter [1:0] SOURCE_CLOCK = 2'b01;
  parameter [2:0] CAPTURE_DELAY = 3'h0;


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


  wire dqs_t, dqs_s;
  wire dq_t;
  wire [QSB:0] dm_w;
  wire [MSB:0] dq_w;


  reg [QSB:0] dqs_p, dqs_n, dm_q;
  reg [MSB:0] dq_q;
  reg cke_q, reset_n_q, cs_n_q;
  reg ras_n_q, cas_n_q, we_n_q, odt_q;
  reg [2:0] ba_q;

  reg valid_q;
  reg [ASB:0] addr_q;
  reg [DSB:0] data_q;


  // -- DFI Read-Data Signal Assignments -- //

  assign dfi_valid_o    = valid_q;
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

  assign ddr3_dqs_p_io  = dqs_t ? {DDR3_MASKS{1'bz}} : dqs_p;
  assign ddr3_dqs_n_io  = dqs_s ? {DDR3_MASKS{1'bz}} : dqs_n;
  assign ddr3_dm_o      = dm_w;
  assign ddr3_dq_io     = dq_t ? {DDR3_WIDTH{1'bz}} : dq_w;


  // -- IOB DDR Register Settings -- //

  localparam CLOCK_POLARITY = 1'b0;
  localparam DATA_ODDR_INIT = 1'b0;
  localparam DQSX_ODDR_INIT = 1'b1;


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

  reg  dqs_q;
  wire dqs_w;

  always @(posedge clock) begin
    if (reset) begin
      dqs_q <= 1'b1;
    end else begin
      dqs_q <= ~dfi_wren_i;
    end
  end

  ODDR #(
      .TXCLK_POL(CLOCK_POLARITY),
      .INIT(DQSX_ODDR_INIT)
  ) dqs_p_oddr_inst[QSB:0] (
      .CLK(~clock),
      .TX (~dfi_wren_i & dqs_q),
      .D0 (1'b1),
      .D1 (1'b0),
      .Q0 (dqs_p),
      .Q1 (dqs_t)
  );

  ODDR #(
      .TXCLK_POL(CLOCK_POLARITY),
      .INIT(DQSX_ODDR_INIT)
  ) dqs_n_oddr_inst[QSB:0] (
      .CLK(~clock),
      .TX (~dfi_wren_i & dqs_q),
      .D0 (1'b0),
      .D1 (1'b1),
      .Q0 (dqs_n),
      .Q1 (dqs_s)
  );


  // -- Write-Data Outputs -- //

  reg clock_270, dat_oe_n;
  reg [DSB:0] data_reg;
  reg [SSB:0] mask_reg;

  always @(negedge clk_ddr) begin
    clock_270 <= clock;
  end

  wire [MSB:0] dq_hi_w, dq_lo_w;
  wire [QSB:0] dm_hi_w, dm_lo_w;

  assign dq_hi_w = data_reg[DSB:DDR3_WIDTH];
  assign dq_lo_w = data_reg[MSB:0];

  assign dm_hi_w = mask_reg[SSB:DDR3_MASKS];
  assign dm_lo_w = mask_reg[QSB:0];

  always @(posedge clock_270) begin
    dat_oe_n <= ~dfi_wren_i;
    mask_reg <= dfi_mask_i;
    data_reg <= dfi_data_i;
  end

  ODDR #(
      .TXCLK_POL(CLOCK_POLARITY),
      .INIT(DATA_ODDR_INIT)
  ) dat_oddr_inst[MSB:0] (
      .CLK(clock_270),
      .TX (dat_oe_n),
      .D0 (dq_lo_w),
      .D1 (dq_hi_w),
      .Q0 (dq_w),
      .Q1 (dq_t)
  );

  ODDR #(
      .TXCLK_POL(CLOCK_POLARITY),
      .INIT(DATA_ODDR_INIT)
  ) dm_oddr_inst[QSB:0] (
      .CLK(clock_270),
      .TX (dat_oe_n),
      .D0 (dm_lo_w),
      .D1 (dm_hi_w),
      .Q0 (dm_w),
      .Q1 ()
  );

  /*
wire dat_d4_t;
wire [MSB:0] dat_d4_w;

OSER4
#( .TXCLK_POL(CLOCK_POLARITY),
   .HWL("false"),
   .GSREN("false"),
   .LSREN("true")
 ) dq_oser4_inst [MSB:0]
 ( .FCLK(~clk_ddr), // 200 MHz, 270 degree phase-shifted
   .PCLK(clock), // 100 MHz
   .RESET(reset),
   .TX0(dfi_wren_i),
   .TX1(dfi_wren_i),
   .D0(dat_lo_w),
   .D1(dat_lo_w),
   .D2(dat_hi_w),
   .D3(dat_hi_w),
   .Q0(dat_d4_w),
   .Q1(dat_d4_t)
 );
*/


  // -- Read Data Valid Signals -- //

  wire rd_en_w;

  shift_register #(
      .WIDTH(1),
      .DEPTH(8)
  ) rd_srl_inst (
      .clock (clock),
      .wren_i(1'b1),
      .data_i(dfi_rden_i),
      .addr_i(CAPTURE_DELAY),
      .data_o(rd_en_w)
  );

  always @(posedge clock) begin
    if (reset) begin
      valid_q <= 1'b0;
    end else begin
      valid_q <= rd_en_w;
    end
  end


  // -- Source-Synchronous Data-Capture Clocks -- //

  wire [QSB:0] dqs_p_i0, dqs_p_i1, dqs_n_i0, dqs_n_i1;

  // One set of these DQS signals will be used for source-synchronous data-
  // capture.
  IDDR #(
      .Q0_INIT(1'b1),
      .Q1_INIT(1'b1)
  ) dqs_p_iddr_inst[QSB:0] (
      .CLK(clk_ddr),
      .D  (ddr3_dqs_p_io),
      .Q0 (dqs_p_i0),
      .Q1 (dqs_p_i1)
  );

  IDDR #(
      .Q0_INIT(1'b1),
      .Q1_INIT(1'b1)
  ) dqs_n_iddr_inst[QSB:0] (
      .CLK(clk_ddr),
      .D  (ddr3_dqs_n_io),
      .Q0 (dqs_n_i0),
      .Q1 (dqs_n_i1)
  );


  // -- Data Capture on Read -- //

  wire [MSB:0] dq_hi, dq_lo;

  always @(posedge clock) begin
    data_q <= {dq_hi, dq_lo};
  end

  // Choose a source-clock for source-synchronous data-capture
  wire [QSB:0] clk_src = SOURCE_CLOCK[1] == 1'b0
             ? (SOURCE_CLOCK[0] == 1'b0 ? dqs_p_i0 : dqs_p_i1)
             : (SOURCE_CLOCK[0] == 1'b0 ? dqs_n_i0 : dqs_n_i1)
             ;

  genvar ii;
  generate
    for (ii = 0; ii < DDR3_MASKS; ii = ii + 1) begin : g_dq_in

      IDDR #(
          .Q0_INIT(1'b1),
          .Q1_INIT(1'b1)
      ) dql_iddr_inst[(ii+1)*8-1:(ii*8)] (
          .CLK(clk_src[ii]),
          .D(ddr3_dq_io[(ii+1)*8-1:(ii*8)]),
          .Q0(dq_lo[(ii+1)*8-1:(ii*8)]),
          .Q1(dq_hi[(ii+1)*8-1:(ii*8)])
      );

    end
  endgenerate


endmodule  // gowin_ddr3_dfi_phy