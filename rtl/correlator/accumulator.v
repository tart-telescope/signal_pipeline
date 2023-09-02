`timescale 1ns / 100ps
`include "tartcfg.v"

module accumulator (  /*AUTOARG*/);

  parameter integer CORES = 18;
  parameter integer NBITS = 5;

  parameter integer TRATE = 30;
  parameter integer TBITS = 5;  // Input MUX bits

  parameter integer WIDTH = 36;  // Accumulator bit-width
  parameter integer SBITS = 6;  // Partial-sums bit-width

  localparam integer MSB = WIDTH - 1;
  localparam integer SSB = SBITS - 1;

  localparam integer PAIRS = CORES * TRATE;
  localparam integer PBITS = NBITS + TBITS;
  localparam integer PSB = PBITS - 1;

  localparam integer CBITS = WIDTH - SBITS + 1;
  // localparam integer COUNT = (1 << CBITS) - 1;
  localparam integer CSB = CBITS - 1;

  input clock_i;
  input reset_ni;
  input enable_i;

  input [SSB:0] revis_i;
  input [SSB:0] imvis_i;

  output [MSB:0] revis_o;
  output [MSB:0] imvis_o;
  output valid_o;
  input ready_i;

  /**
   *  SRAMs that store the partially-accumulated visibilities.
   */
  reg [MSB:0]    rsram [PAIRS];
  reg [MSB:0]    isram [PAIRS];
  reg [PSB:0]    raddr = {PBITS{1'b0}};
  reg [MSB:0] r_dat, i_dat;
  wire [PSB:0] rnext = raddr + 1;
  reg          accum = 1'b0;

  // todo:
  always @(posedge clock_i) begin
    if (!reset_ni) begin
      raddr <= {PBITS{1'b0}};
      accum <= 1'b0;
    end else if (enable_i) begin
      if (rnext == PAIRS) begin
        raddr <= {PBITS{1'b0}};
      end else begin
        raddr <= raddr + 1;
      end

      r_dat <= rsram[raddr];
      i_dat <= isram[raddr];
      accum <= 1'b1;  // Enable for accumulator stage
    end else begin
      raddr <= raddr;
      accum <= 1'b0;
    end
  end

  /**
   *  Accumulate the partial-sums into full-width visibilities.
   */
  reg [MSB:0] r_acc, i_acc;
  reg write = 1'b0;

  always @(posedge clock_i) begin
    if (!reset_ni) begin
      write <= 1'b0;
    end else if (accum) begin
      r_acc <= r_dat + revis_i;
      i_acc <= i_dat + imvis_i;
      write <= 1'b1;
    end else begin
      write <= 1'b0;
    end
  end

  /**
   *  Write back the partial-sums into the SRAMs.
   */
  reg  [PSB:0] waddr = {PBITS{1'b0}};
  wire [PSB:0] wnext = waddr + 1;
  reg          wlast = 1'b0;

  always @(posedge clock_i) begin
    if (!reset_ni) begin
      waddr <= {PBITS{1'b0}};
      wlast <= 1'b0;
    end else if (write) begin
      if (wnext == PAIRS) begin
        waddr <= {PBITS{1'b0}};
        wlast <= 1'b1;
      end else begin
        waddr <= waddr + 1;
        wlast <= 1'b0;
      end

      rsram[waddr] <= r_acc;
      isram[waddr] <= i_acc;
    end else begin
      wlast <= 1'b0;
    end
  end

  /**
   *  AXI4-Stream output.
   */
  reg [MSB:0] revis, imvis;
  reg valid = 1'b0;
  reg [CSB:0] count = {CBITS{1'b0}};
  wire [CSB:0] cnext = count + 1;

  assign revis_o = revis;
  assign imvis_o = imvis;

  always @(posedge clock_i) begin
    if (!reset_ni) begin
      count <= {CBITS{1'b0}};
      valid <= 1'b0;
    end else begin
      if (wlast) begin
        if (cnext[CSB]) begin
          count <= 1'b0;
        end else begin
          count <= cnext;
        end
      end

      if (cnext == 0) begin
        valid <= 1'b1;
        revis <= r_acc;
        imvis <= i_acc;
      end else if (ready_i) begin
        valid <= 1'b0;
      end
    end
  end

endmodule  // correlator
