`timescale 1ns / 100ps
//-----------------------------------------------------------------
//              Lightweight DDR3 Memory Controller
//                            V0.5
//                     Ultra-Embedded.com
//                     Copyright 2020-21
//
//                   admin@ultra-embedded.com
//
//                     License: Apache 2.0
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

module ddr3_axi
#(
      parameter DDR_MHZ          = 100
    , parameter DDR_WRITE_LATENCY = 4
    , parameter DDR_READ_LATENCY = 4
)
(
      input           clock
    , input           reset

    , input           axi_awvalid_i
    , output          axi_awready_o
    , input  [ 31:0]  axi_awaddr_i
    , input  [  3:0]  axi_awid_i
    , input  [  7:0]  axi_awlen_i
    , input  [  1:0]  axi_awburst_i
    , input           axi_wvalid_i
    , output          axi_wready_o
    , input  [ 31:0]  axi_wdata_i
    , input  [  3:0]  axi_wstrb_i
    , input           axi_wlast_i
    , output          axi_bvalid_o
    , input           axi_bready_i
    , output [  1:0]  axi_bresp_o
    , output [  3:0]  axi_bid_o
    , input           axi_arvalid_i
    , output          axi_arready_o
    , input  [ 31:0]  axi_araddr_i
    , input  [  3:0]  axi_arid_i
    , input  [  7:0]  axi_arlen_i
    , input  [  1:0]  axi_arburst_i
    , output          axi_rvalid_o
    , input           axi_rready_i
    , output [ 31:0]  axi_rdata_o
    , output [  1:0]  axi_rresp_o
    , output [  3:0]  axi_rid_o
    , output          axi_rlast_o

    , input  [ 31:0]  dfi_rddata_i
    , input           dfi_rddata_valid_i
    , input  [  1:0]  dfi_rddata_dnv_i
    , output [ 14:0]  dfi_address_o
    , output [  2:0]  dfi_bank_o
    , output          dfi_cas_n_o
    , output          dfi_cke_o
    , output          dfi_cs_n_o
    , output          dfi_odt_o
    , output          dfi_ras_n_o
    , output          dfi_reset_n_o
    , output          dfi_we_n_o
    , output [ 31:0]  dfi_wrdata_o
    , output          dfi_wrdata_en_o
    , output [  3:0]  dfi_wrdata_mask_o
    , output          dfi_rddata_en_o
);


// -- AXI to/from DDR3 (Width-)Matching -- //

wire [ 31:0]  ram_addr_w;
wire [ 15:0]  ram_wr_w;
wire          ram_rd_w;
wire          ram_accept_w;
wire [127:0]  ram_write_data_w;
wire [127:0]  ram_read_data_w;
wire [ 15:0]  ram_req_id_w;
wire [ 15:0]  ram_resp_id_w;
wire          ram_ack_w;
wire          ram_error_w;

ddr3_axi_pmem
u_axi
(
    .clock(clock),
    .reset(reset),

    .axi_awvalid_i(axi_awvalid_i), // AXI4 Write Address Port
    .axi_awready_o(axi_awready_o),
    .axi_awid_i(axi_awid_i),
    .axi_awlen_i(axi_awlen_i),
    .axi_awburst_i(axi_awburst_i),
    .axi_awaddr_i(axi_awaddr_i),

    .axi_wvalid_i(axi_wvalid_i), // AXI4 Write Data Port
    .axi_wready_o(axi_wready_o),
    .axi_wlast_i(axi_wlast_i),
    .axi_wstrb_i(axi_wstrb_i),
    .axi_wdata_i(axi_wdata_i),

    .axi_bvalid_o(axi_bvalid_o), // AXI4 Write Response Port
    .axi_bready_i(axi_bready_i),
    .axi_bresp_o(axi_bresp_o),
    .axi_bid_o(axi_bid_o),

    .axi_arvalid_i(axi_arvalid_i), // AXI4 Read Address Port
    .axi_arready_o(axi_arready_o),
    .axi_arid_i(axi_arid_i),
    .axi_arlen_i(axi_arlen_i),
    .axi_arburst_i(axi_arburst_i),
    .axi_araddr_i(axi_araddr_i),

    .axi_rready_i(axi_rready_i), // AXI4 Read Data Port
    .axi_rvalid_o(axi_rvalid_o),
    .axi_rlast_o(axi_rlast_o),
    .axi_rresp_o(axi_rresp_o),
    .axi_rid_o(axi_rid_o),
    .axi_rdata_o(axi_rdata_o),
    
    // DDR3 SDRAM Interface
    .ram_addr_o(ram_addr_w),
    .ram_accept_i(ram_accept_w),
    .ram_wr_o(ram_wr_w),
    .ram_rd_o(ram_rd_w),
    .ram_req_id_o(ram_req_id_w),
    .ram_write_data_o(ram_write_data_w),
    .ram_ack_i(ram_ack_w),
    .ram_error_i(ram_error_w),
    .ram_read_data_i(ram_read_data_w),
    .ram_resp_id_i(ram_resp_id_w)
);


// -- DDR3 Controller -- //

ddr3_core
#(
     .DDR_MHZ(DDR_MHZ)
    ,.DDR_WRITE_LATENCY(DDR_WRITE_LATENCY)
    ,.DDR_READ_LATENCY(DDR_READ_LATENCY)
)
u_core
(
     .clock(clock)
    ,.reset(reset)

    ,.mem_wr_i(ram_wr_w)
    ,.mem_rd_i(ram_rd_w)
    ,.mem_req_id_i(ram_req_id_w)
    ,.mem_addr_i(ram_addr_w)
    ,.mem_write_data_i(ram_write_data_w)
    ,.mem_accept_o(ram_accept_w)
    ,.mem_ack_o(ram_ack_w)
    ,.mem_error_o(ram_error_w)
    ,.mem_read_data_o(ram_read_data_w)
    ,.mem_resp_id_o(ram_resp_id_w)

    ,.cfg_enable_i(1'b1)
    ,.cfg_stb_i(1'b0)
    ,.cfg_data_i(32'b0)
    ,.cfg_stall_o()

    ,.dfi_address_o(dfi_address_o)
    ,.dfi_bank_o(dfi_bank_o)
    ,.dfi_cas_n_o(dfi_cas_n_o)
    ,.dfi_cke_o(dfi_cke_o)
    ,.dfi_cs_n_o(dfi_cs_n_o)
    ,.dfi_odt_o(dfi_odt_o)
    ,.dfi_ras_n_o(dfi_ras_n_o)
    ,.dfi_reset_n_o(dfi_reset_n_o)
    ,.dfi_we_n_o(dfi_we_n_o)
    ,.dfi_wrdata_o(dfi_wrdata_o)
    ,.dfi_wrdata_en_o(dfi_wrdata_en_o)
    ,.dfi_wrdata_mask_o(dfi_wrdata_mask_o)
    ,.dfi_rddata_en_o(dfi_rddata_en_o)
    ,.dfi_rddata_i(dfi_rddata_i)
    ,.dfi_rddata_valid_i(dfi_rddata_valid_i)
    ,.dfi_rddata_dnv_i(dfi_rddata_dnv_i)
);


endmodule // ddr3_axi
