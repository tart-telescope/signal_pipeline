`timescale 1ns / 100ps
//-----------------------------------------------------------------
// Copyright 2020-21 Ultra-Embedded.com
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------

module ddr3_core_tb;

// -- Simulation Settings -- //

localparam DDR_MHZ = 100;
localparam DDR_WRITE_LATENCY = 4;
localparam DDR_READ_LATENCY = 5;


// -- Simulation Data -- //

initial begin
  $dumpfile("ddr3_core_tb.vcd");
  $dumpvars(0, ddr3_core_tb);

  #80000 $finish; // todo ...
end


// -- Globals -- //

reg osc = 1'b1;
reg ddr = 1'b1;
reg rst = 1'b0;

always #5.0 osc <= ~osc;
always #2.5 ddr <= ~ddr;

initial begin
  rst <= 1'b1;
  #200 rst <= 1'b0;
end


wire locked, clock, reset;
wire clk_ddr, clk_ddr_dqs, clk_ref;

/*
gowin_rpll
#(
  .FCLKIN("27"),
  .IDIV_SEL(8),
  .FBDIV_SEL(17),
  .ODIV_SEL(3)
) RPLL_inst
(
 .clkin(osc),
 .lock(locked),
 .clkout(clk_ddr),
 .clkref(clk_ref)
 );
*/


assign clock = osc;
assign reset = rst | ~locked;

assign #50 locked = 1'b1;
assign clk_ddr = ddr;


// -- DDR3 and Controller Signals -- //

wire          ddr3_clk_w;
wire          ddr3_cke_w;
wire          ddr3_reset_n_w;
wire          ddr3_ras_n_w;
wire          ddr3_cas_n_w;
wire          ddr3_we_n_w;
wire          ddr3_cs_n_w;
wire [  2:0]  ddr3_ba_w;
wire [ 14:0]  ddr3_addr_w;
wire          ddr3_odt_w;
wire [  1:0]  ddr3_dm_w;
wire [  1:0]  ddr3_dqs_w;
wire [ 15:0]  ddr3_dq_w;

wire  [ 14:0] dfi_address;
wire  [  2:0] dfi_bank;
wire          dfi_cas_n;
wire          dfi_cke;
wire          dfi_cs_n;
wire          dfi_odt;
wire          dfi_ras_n;
wire          dfi_reset_n;
wire          dfi_we_n;
wire  [ 31:0] dfi_wrdata;
wire          dfi_wrdata_en;
wire  [  3:0] dfi_wrdata_mask;
wire          dfi_rddata_en;
wire [ 31:0]  dfi_rddata;
wire dfi_rddata_dnv;
wire          dfi_rddata_valid;

reg  [ 15:0]  ram_wr;
reg           ram_rd;
reg  [ 31:0]  ram_addr;
reg  [127:0]  ram_write_data;
reg  [ 15:0]  ram_req_id;
wire          ram_accept;
wire          ram_ack;
wire          ram_error;
wire [ 15:0]  ram_resp_id;
wire [127:0]  ram_read_data;


// -- Initialisation -- //

reg [127:0] data;

initial begin : Stimulus
  ram_wr         = 0;
  ram_rd         = 0;
  ram_addr       = 0;
  ram_write_data = 0;
  ram_req_id     = 0;

  @(posedge clock);

  ram_write(0,  128'hffeeddccbbaa99887766554433221100, 16'hFFFF);
  ram_write(16, 128'hbeaffeadd0d0600d5555AAAA00000000, 16'hFFFF);
  ram_write(32, 128'hffffffff111111112222222233333333, 16'hFFFF);

  ram_read(0, data);
  if (data != 128'hffeeddccbbaa99887766554433221100)
  begin
    $fatal(1, "ERROR: Data mismatch!");
  end

  ram_read(16, data);
  if (data != 128'hbeaffeadd0d0600d5555AAAA00000000)
  begin
    $fatal(1, "ERROR: Data mismatch!");
  end

  ram_read(32, data);
  if (data != 128'hffffffff111111112222222233333333)
  begin
    $fatal(1, "ERROR: Data mismatch!");
  end

  #1000
      @(posedge clock);   
  $finish;
end


//----------------------------------------------------------------------------
//
//  DRAM Model
//
//----------------------------------------------------------------------------

wire          ddr3_ck_p_w;
wire          ddr3_ck_n_w;
wire [  1:0]  ddr3_dqs_p_w;
wire [  1:0]  ddr3_dqs_n_w;

ddr3
ddr3_sdram_inst
(
     .rst_n(ddr3_reset_n_w)
    ,.ck(ddr3_ck_p_w)
    ,.ck_n(ddr3_ck_n_w)
    ,.cke(ddr3_cke_w)
    ,.cs_n(ddr3_cs_n_w)
    ,.ras_n(ddr3_ras_n_w)
    ,.cas_n(ddr3_cas_n_w)
    ,.we_n(ddr3_we_n_w)
    ,.dm_tdqs(ddr3_dm_w)
    ,.ba(ddr3_ba_w)
    ,.addr(ddr3_addr_w[13:0])
    ,.dq(ddr3_dq_w)
    ,.dqs(ddr3_dqs_p_w)
    ,.dqs_n(ddr3_dqs_n_w)
    ,.tdqs_n()
    ,.odt(ddr3_odt_w)
);


// -- DDR3 PHY -- //

generic_ddr3_dfi_phy
#( .ADDR_BITS(15),
    .DEFAULT_CL(DDR_READ_LATENCY),
    .DEFAULT_CWL(DDR_WRITE_LATENCY)
)
u_phy
(
     .clock(clock)
    ,.reset(reset)
    ,.clk_ddr(clk_ddr)

,.cfg_valid_i(1'b0)
,.cfg_data_i({16'h0000, 4'h4, 4'h5, 8'h00})

    ,.dfi_cke_i(dfi_cke)
    ,.dfi_reset_n_i(dfi_reset_n)
    ,.dfi_cs_n_i(dfi_cs_n)
    ,.dfi_ras_n_i(dfi_ras_n)
    ,.dfi_cas_n_i(dfi_cas_n)
    ,.dfi_we_n_i(dfi_we_n)
    ,.dfi_odt_i(dfi_odt)
    ,.dfi_bank_i(dfi_bank)
    ,.dfi_addr_i(dfi_address)

    ,.dfi_wren_i(dfi_wrdata_en)
    ,.dfi_mask_i(dfi_wrdata_mask)
    ,.dfi_data_i(dfi_wrdata)

    ,.dfi_rden_i(dfi_rddata_en)
    ,.dfi_valid_o(dfi_rddata_valid)
    ,.dfi_data_o(dfi_rddata)
    // ,.dfi_rddata_dnv_o(dfi_rddata_dnv)

    ,.ddr3_ck_p_o(ddr3_ck_p_w)
    ,.ddr3_ck_n_o(ddr3_ck_n_w)
    ,.ddr3_cke_o(ddr3_cke_w)
    ,.ddr3_reset_n_o(ddr3_reset_n_w)
    ,.ddr3_cs_n_o(ddr3_cs_n_w)
    ,.ddr3_ras_n_o(ddr3_ras_n_w)
    ,.ddr3_cas_n_o(ddr3_cas_n_w)
    ,.ddr3_we_n_o(ddr3_we_n_w)
    ,.ddr3_odt_o(ddr3_odt_w)
    ,.ddr3_ba_o(ddr3_ba_w)
    ,.ddr3_a_o(ddr3_addr_w)
    ,.ddr3_dm_o(ddr3_dm_w)
    ,.ddr3_dqs_p_io(ddr3_dqs_p_w)
    ,.ddr3_dqs_n_io(ddr3_dqs_n_w)
    ,.ddr3_dq_io(ddr3_dq_w)
);


//----------------------------------------------------------------------------
//
//  DDR Core Under Test
//
//----------------------------------------------------------------------------

ddr3_core
#(
    .DDR_WRITE_LATENCY(DDR_WRITE_LATENCY),
    .DDR_READ_LATENCY(DDR_READ_LATENCY),
    .DDR_MHZ(DDR_MHZ)
)
ddr_core_inst
(
    .clock(clock), // system clock
    .reset(reset), // synchronous reset

    // Configuration (unused),
    .cfg_enable_i(1'b1),
    .cfg_stb_i(1'b0),
    .cfg_data_i(32'b0),
    .cfg_stall_o(),

    .mem_wr_i(ram_wr),
    .mem_rd_i(ram_rd),
    .mem_addr_i(ram_addr),
    .mem_write_data_i(ram_write_data),
    .mem_req_id_i(ram_req_id),
    .mem_accept_o(ram_accept),
    .mem_ack_o(ram_ack),
    .mem_error_o(ram_error),
    .mem_resp_id_o(ram_resp_id),
    .mem_read_data_o(ram_read_data),

    .dfi_address_o(dfi_address),
    .dfi_bank_o(dfi_bank),
    .dfi_cas_n_o(dfi_cas_n),
    .dfi_cke_o(dfi_cke),
    .dfi_cs_n_o(dfi_cs_n),
    .dfi_odt_o(dfi_odt),
    .dfi_ras_n_o(dfi_ras_n),
    .dfi_reset_n_o(dfi_reset_n),
    .dfi_we_n_o(dfi_we_n),
    .dfi_wrdata_o(dfi_wrdata),
    .dfi_wrdata_en_o(dfi_wrdata_en),
    .dfi_wrdata_mask_o(dfi_wrdata_mask),
    .dfi_rddata_en_o(dfi_rddata_en),
    .dfi_rddata_i(dfi_rddata),
    .dfi_rddata_valid_i(dfi_rddata_valid),
    .dfi_rddata_dnv_i({dfi_rddata_dnv, dfi_rddata_dnv})
);


//-----------------------------------------------------------------
// ram_read: Perform read transfer (128-bit)
//-----------------------------------------------------------------
task ram_read;
    input  [31:0]  addr;
    output [127:0] data;
begin
    ram_rd     <= 1'b1;
    ram_addr   <= addr;
    ram_req_id <= ram_req_id + 1;
    @(posedge clock);

    while (!ram_accept)
    begin
        @(posedge clock);
    end
    ram_rd     <= 1'b0;

    while (!ram_ack)
    begin
        @(posedge clock);
    end

    data = ram_read_data;
end
endtask


//-----------------------------------------------------------------
// ram_write: Perform write transfer (128-bit)
//-----------------------------------------------------------------
task ram_write;
    input [31:0]  addr;
    input [127:0] data;
    input [15:0]  mask;
begin
    ram_wr         <= mask;
    ram_addr       <= addr;
    ram_write_data <= data;
    ram_req_id     <= ram_req_id + 1;
    @(posedge clock);

    while (!ram_accept)
    begin
        @(posedge clock);
    end
    ram_wr <= 16'b0;

    while (!ram_ack)
    begin
        @(posedge clock);
    end
end
endtask


endmodule // ddr3_core_tb
