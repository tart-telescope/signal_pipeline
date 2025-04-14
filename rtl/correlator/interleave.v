`timescale 1ns / 100ps
/**
 * FIFO for halving the width of a sparse/aperiodic data stream.
 * 
 * Todo:
 *  - 'm_tdata' output is combinational (from 2:1 MUX);
 *  - 'tready_w' input is combinational, to synchronous FIFO;
 */
module interleave #(
    parameter  integer WIDTH = 7,
    localparam integer KEEPS = WIDTH / 4,
    localparam integer MSB   = WIDTH - 1,
    localparam integer USB   = WIDTH + MSB,
    parameter  integer DEPTH = 32,
    localparam integer ABITS = $clog2(DEPTH),
    localparam integer ASB   = ABITS - 1
) (
    input clock,
    input reset,

    input s_tvalid,
    output s_tready,
    input [USB:0] s_tdata,

    output m_tvalid,
    input m_tready,
    output [MSB:0] m_tdata
);

  reg odd_q;
  wire tvalid_w, tready_w;
  wire [USB:0] tdata_w;
  wire [ASB:0] level_w;

  assign tready_w = odd_q && m_tvalid && m_tready;
  assign m_tdata  = odd_q ? tdata_w[USB:WIDTH] : tdata_w[MSB:0];

  /**
   * ToP:
   *  - output 2 words, while fetching on each odd word accepted;
   */
  always @(posedge clock) begin
    if (reset || !m_tvalid) begin
      odd_q <= 1'b0;
    end else if (m_tready) begin
      odd_q <= ~odd_q;
    end
  end

  axis_sfifo #(
      .WIDTH(WIDTH + WIDTH),
      .DEPTH(DEPTH),
      .TKEEP(0),
      .TLAST(0)
  ) U_SFIFO1 (
      .clock(clock),
      .reset(reset),

      .level_o(level_w),

      .s_tvalid(s_tvalid),
      .s_tready(s_tready),
      .s_tkeep ({KEEPS{1'b0}}),
      .s_tlast (1'b0),
      .s_tdata (s_tdata),

      .m_tvalid(m_tvalid),
      .m_tready(tready_w),
      .m_tkeep (),
      .m_tlast (),
      .m_tdata (tdata_w)
  );

endmodule  /* interleave */
