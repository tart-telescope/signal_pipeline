`timescale 1ns / 100ps
/**
 * Single-clock, LOW-latency (SLOW) FIFO.
 */
module slow_fifo (
    clock,
    reset,

    wren_i,
    accept_o,
    data_i,

    rden_i,
    valid_o,
    data_o
);

  parameter  WIDTH = 8;
  localparam MSB   = WIDTH - 1;

  parameter  ABITS = 4;
  localparam DEPTH = 1 << ABITS;
  localparam ASB   = ABITS - 1;
  localparam ADDRS = ABITS + 1;


  input          clock;
  input          reset;

  input          wren_i;
  output         accept_o;
  input [MSB:0]  data_i;

  input          rden_i;
  output         valid_o;
  output [MSB:0] data_o;


  reg [MSB:0]    sram   [0:DEPTH-1];
  reg [ASB:0]    rd_ptr;
  reg [ASB:0]    wr_ptr;
  reg [ABITS:0]  count;


  // Low-latency status and data outputs
  assign accept_o = (count != DEPTH);
  assign valid_o  = (count != 0);
  assign data_o   = sram[rd_ptr];


  always @(posedge clock) begin
    if (reset) begin
      count  <= {ADDRS{1'b0}};
      rd_ptr <= {ABITS{1'b0}};
      wr_ptr <= {ABITS{1'b0}};
    end else begin
      // Store
      if (wren_i && accept_o) begin
        sram[wr_ptr] <= data_i;
        wr_ptr       <= wr_ptr + 1;
      end

      // Fetch
      if (rden_i && valid_o) begin
        rd_ptr <= rd_ptr + 1;
      end

      // Count up && down
      if ((wren_i && accept_o) && !(rden_i && valid_o)) begin
        count <= count + 1;
      end else if (!(wren_i && accept_o) && (rden_i && valid_o)) begin
        count <= count - 1;
      end
    end
  end


endmodule  // slow_fifo
