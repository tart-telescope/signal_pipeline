`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
//
// Module Name: bulk_ep_out
// Project Name: axis_usbd
//
// Based on project 'https://github.com/ObKo/USBCore'
// License: MIT
//  Copyright (c) 2021 Dmitry Matyunin
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//////////////////////////////////////////////////////////////////////////////////

module bulk_ep_out #(
    parameter FPGA_VENDOR = "xilinx",
    parameter FPGA_FAMILY = "7series"
) (
    input  wire reset_n,

    input  wire bulk_ep_out_clock,
    input  wire bulk_ep_out_xfer_i, // todo: also unconnected in original ...
    output wire bulk_ep_out_ready_read_o,

    input wire bulk_ep_out_tvalid_i,
    output wire bulk_ep_out_tready_o,
    input wire bulk_ep_out_tlast_i,
    input wire [7:0] bulk_ep_out_tdata_i,

    input wire axis_aclk,
    output wire axis_tvalid_o,
    input wire axis_tready_i,
    output wire axis_tlast_o,
    output wire [7:0] axis_tdata_o
);

  wire prog_full;
  reg  blk_xfer_out_ready_read_out;

  // todo: ...
  assign prog_full = bulk_ep_out_tready_o;
  assign bulk_ep_out_ready_read_o = blk_xfer_out_ready_read_out;

  /* Full Latch */
  always @(posedge bulk_ep_out_clock) begin
    // todo: WTF !?
    blk_xfer_out_ready_read_out <= ~prog_full;
  end

  axis_afifo #(
      .WIDTH(8),
      .ABITS(4)
  ) axis_afifo_inst (
      .s_aresetn(reset_n),

      .m_aclk(axis_aclk),
      .m_tvalid_o(axis_tvalid_o),
      .m_tready_i(axis_tready_i),
      .m_tlast_o(axis_tlast_o),
      .m_tdata_o(axis_tdata_o),

      .s_aclk(bulk_ep_out_clock),
      .s_tvalid_i(bulk_ep_out_tvalid_i),
      .s_tready_o(bulk_ep_out_tready_o),
      .s_tlast_i(bulk_ep_out_tlast_i),
      .s_tdata_i(bulk_ep_out_tdata_i)
  );

endmodule
