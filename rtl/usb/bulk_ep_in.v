`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
//
// Module Name: bulk_ep_in
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

module bulk_ep_in (
    reset_n,

    axis_aclk,
    axis_tvalid_i,
    axis_tready_o,
    axis_tlast_i,
    axis_tdata_i,

    bulk_ep_in_clock,
    bulk_ep_in_xfer_i,
    bulk_ep_in_has_data_o,

    bulk_ep_in_tvalid_o,
    bulk_ep_in_tready_i,
    bulk_ep_in_tlast_o,
    bulk_ep_in_tdata_o
);

  parameter FPGA_VENDOR = "xilinx";
  parameter FPGA_FAMILY = "7series";

  input wire reset_n;

  input wire axis_aclk;
  input wire axis_tvalid_i;
  output wire axis_tready_o;
  input wire axis_tlast_i;
  input wire [7:0] axis_tdata_i;

  input wire bulk_ep_in_clock;
  input wire bulk_ep_in_xfer_i;
  output wire bulk_ep_in_has_data_o;

  output wire bulk_ep_in_tvalid_o;
  input wire bulk_ep_in_tready_i;
  output wire bulk_ep_in_tlast_o;
  output wire [7:0] bulk_ep_in_tdata_o;

  localparam [0:0] STATE_IDLE = 0, STATE_XFER = 1;

  reg [0:0] state;

  wire prog_full;
  wire was_last_usb;
  wire prog_full_usb;
  reg was_last;
  reg bulk_xfer_in_has_data_out;

  assign bulk_ep_in_has_data_o = bulk_xfer_in_has_data_out;
  assign prog_full = ~axis_tready_o;

  always @(posedge bulk_ep_in_clock) begin
    if (reset_n == 1'b0) begin
      state <= STATE_IDLE;
      bulk_xfer_in_has_data_out <= 1'b0;
    end else begin
      case (state)
        STATE_IDLE: begin
          if ((was_last_usb == 1'b1) || (prog_full_usb == 1'b1)) begin
            bulk_xfer_in_has_data_out <= 1'b1;
          end
          if (bulk_ep_in_xfer_i == 1'b1) begin
            state <= STATE_XFER;
          end
        end
        STATE_XFER: begin
          if (bulk_ep_in_xfer_i == 1'b0) begin
            bulk_xfer_in_has_data_out <= 1'b0;
            state <= STATE_IDLE;
          end
        end
      endcase
    end
  end

  always @(posedge axis_aclk) begin
    if (reset_n == 1'b0) begin
      was_last <= 1'b0;
    end else begin
      if ((axis_tvalid_i == 1'b1) && (axis_tready_o == 1'b1) && (axis_tlast_i == 1'b1)) begin
        was_last <= 1'b1;
      end else if ((axis_tvalid_i == 1'b1) && (axis_tready_o == 1'b1) && (axis_tlast_i == 1'b0)) begin
        was_last <= 1'b0;
      end
    end
  end

  axis_afifo #(
      .WIDTH(8),
      .ABITS(4)
  ) axis_afifo_inst (
      .s_aresetn(reset_n),

      .s_aclk(axis_aclk),
      .s_tvalid_i(axis_tvalid_i),
      .s_tready_o(axis_tready_o),
      .s_tlast_i(axis_tlast_i),
      .s_tdata_i(axis_tdata_i),

      .m_aclk(bulk_ep_in_clock),
      .m_tvalid_o(bulk_ep_in_tvalid_o),
      .m_tready_i(bulk_ep_in_tready_i),
      .m_tlast_o(bulk_ep_in_tlast_o),
      .m_tdata_o(bulk_ep_in_tdata_o)
  );

  arch_cdc_array #(
      .FPGA_VENDOR(FPGA_VENDOR),
      .FPGA_FAMILY(FPGA_FAMILY),
      .WIDTH(2)
  ) arch_cdc_array_inst (
      .src_clk (axis_aclk),
      .src_data({prog_full, was_last}),
      .dst_clk (bulk_ep_in_clock),
      .dst_data({prog_full_usb, was_last_usb})
  );

endmodule  // bulk_ep_in
