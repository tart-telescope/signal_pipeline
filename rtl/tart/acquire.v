`timescale 1ns / 100ps
module acquire #(
    parameter CHUNK = 512,
    parameter RADIOS = 24,
    localparam MSB = RADIOS - 1,
    parameter SRAM_BYTES = 2048
) (
    input sig_clock,
    input bus_clock,
    input bus_reset,

    // AXI4 Stream of antenna data
    input sig_valid_i,
    input sig_last_i,
    input [MSB:0] sig_idata_i,
    input [MSB:0] sig_qdata_i,

    // AXI4 Stream of raw (radio ADC) data
    output raw_tvalid_o,
    input raw_tready_i,
    output raw_tlast_o,
    output [7:0] raw_tdata_o
);

  localparam KEEPS = (RADIOS * 2 + 7) / 8;
  localparam WIDTH = KEEPS << 3;
  localparam WSB = WIDTH - 1;
  localparam KSB = KEEPS - 1;

  wire tvalid_w, tready_w, tlast_w, xvalid_w, xready_w, xkeep_w, xlast_w;
  wire [KSB:0] tkeep_w;
  wire [WSB:0] tdata_w;
  wire [  7:0] xdata_w;

  assign tkeep_w = {KEEPS{tvalid_w}};

  axis_afifo #(
      .WIDTH(WIDTH),
      .TLAST(0),
      .ABITS(4)
  ) U_AFIFO1 (
      .aresetn (~bus_reset),
      .s_aclk  (sig_clock),
      .s_tvalid(sig_valid_i),
      .s_tready(),
      .s_tlast (1'b1),
      .s_tdata ({sig_qdata_i, sig_idata_i}),
      .m_aclk  (bus_clock),
      .m_tvalid(tvalid_w),
      .m_tready(tready_w),
      .m_tlast (),
      .m_tdata (tdata_w)
  );

  axis_adapter #(
      .S_DATA_WIDTH(8),
      .S_KEEP_ENABLE(1),
      .S_KEEP_WIDTH(1),
      .M_DATA_WIDTH(WIDTH),
      .M_KEEP_ENABLE(1),
      .M_KEEP_WIDTH(KEEPS),
      .ID_ENABLE(0),
      .ID_WIDTH(1),
      .DEST_ENABLE(0),
      .DEST_WIDTH(1),
      .USER_ENABLE(0),
      .USER_WIDTH(1)
  ) U_ADAPT1 (
      .clk(bus_clock),
      .rst(bus_reset),

      .s_axis_tvalid(tvalid_w),  // AXI input
      .s_axis_tready(tready_w),
      .s_axis_tkeep(tkeep_w),
      .s_axis_tlast(1'b0),
      .s_axis_tid(1'b0),
      .s_axis_tdest(1'b0),
      .s_axis_tuser(1'b0),
      .s_axis_tdata(tdata_w),

      .m_axis_tvalid(xvalid_w),
      .m_axis_tready(xready_w),
      .m_axis_tkeep(xkeep_w),
      .m_axis_tlast(),
      .m_axis_tid(),
      .m_axis_tdest(),
      .m_axis_tuser(),
      .m_axis_tdata(xdata_w)  // AXI output
  );

  //
  // Todo:
  //  - generate a 'save' when 'sig_valid_i' deasserts;
  //
  packet_fifo #(
      .WIDTH(8),
      .DEPTH(SRAM_BYTES),
      .STORE_LASTS(1),
      .SAVE_ON_LAST(0),
      .LAST_ON_SAVE(1),
      .NEXT_ON_LAST(1),
      .USE_LENGTH(1),
      .MAX_LENGTH(CHUNK),
      .OUTREG(2)
  ) U_PFIFO1 (
      .clock(bus_clock),
      .reset(bus_reset),

      .level_o(),
      .drop_i (1'b0),
      .save_i (1'b0),
      .redo_i (1'b0),
      .next_i (1'b0),

      .s_tvalid(xvalid_w),
      .s_tready(xready_w),
      .s_tkeep (xkeep_w),
      .s_tlast (1'b0),
      .s_tdata (xdata_w),

      .m_tvalid(raw_tvalid_o),
      .m_tready(raw_tready_i),
      .m_tlast (raw_tlast_o),
      .m_tdata (raw_tdata_o)
  );

endmodule  /* acquire */
