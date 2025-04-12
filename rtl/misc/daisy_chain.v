`timescale 1ns / 100ps
/**
 * Merge parallel outputs into a daisy-chain of values.
 *
 * Note:
 *  - just a 2:1 MUX plus followed by an output register, for each daisy-chain
 *    element;
 *  - generic enough to be reusable, though the ports need to be made more
 *    general-purpose;
 *
 * Todo:
 *  - make into a general-purpose module;
 *
 */
module daisy_chain #(
    parameter integer LENGTH = 8,
    parameter integer LSB = LENGTH - 1,
    parameter integer WIDTH = 8,
    localparam integer MSB = WIDTH - 1,
    localparam integer WBITS = LENGTH * WIDTH,
    localparam integer WSB = WBITS - 1,
    localparam integer KEEPS = (WIDTH + 7) / 8,
    localparam integer KSB = KEEPS - 1,
    localparam integer JBITS = KEEPS * LENGTH,
    localparam integer JSB = JBITS - 1
) (
    input clock,
    input reset,

    output err_stall_o,

    // From (parallel) outputs of correlators
    input  [LSB:0] par_tvalid_i,
    output [LSB:0] par_tready_o,  // todo: not really possible !?
    input  [LSB:0] par_tlast_i,   // todo: use only last element of chain !?
    input  [JSB:0] par_tkeep_i,   // todo: juice not worth the squeeze !?
    input  [WSB:0] par_tdata_i,

    // Daisy-chain outputs
    output seq_tvalid_o,
    input seq_tready_i,
    output seq_tlast_o,  // todo: batch-lasts
    output [KSB:0] seq_tkeep_o,
    output [MSB:0] seq_tdata_o
);

  // -- State & Signals -- //

  localparam [MSB:0] YUCKS = {WIDTH{1'bx}};
  localparam integer PBITS = WBITS - LENGTH;
  localparam integer PSB = PBITS - 1;
  localparam [JSB:0] JUCKS = {KEEPS{1'bx}};

  reg stall_q;
  reg [LSB:0] tvalid_q, tlast_q;
  reg [JSB:0] tkeep_q;
  reg [WSB:0] tdata_q;
  wire [LSB:0] src_valid_w, src_tlast_w;
  wire [WSB:0] src_tdata_w;

  // -- Output Assignments -- //

  assign err_stall_o  = stall_q;

  assign par_tready_o = {LENGTH{1'b1}};

  assign seq_tvalid_o = tvalid_q[LSB];
  assign seq_tlast_o  = tlast_q[LSB];
  assign seq_tkeep_o  = tkeep_q[JSB:KBITS];
  assign seq_tdata_o  = tdata_q[WSB:PBITS];

  // -- Internal Assignments -- //

  assign src_tvalid_w = {tvalid_q[LENGTH-2:0], 1'b0};  // Source(-chain) valids
  assign src_tlast_w  = {tlast_q[LENGTH-2:0], 1'b0};  // Source(-chain) lasts
  assign src_tkeep_w  = {tkeep_q[JSB-KEEPS:0], JUCKS};
  assign src_tdata_w  = {tdata_q[PSB:0], YUCKS};

  // -- Pipeline Logics -- //

  // Todo: make good, if we want to support back-pressure.
  always @(posedge clock) begin
    if (reset) begin
      stall_q <= 1'b0;
    end else begin
      stall_q <= stall_q || tvalid_q && !seq_tready_i;
    end
  end

  // -- Output select & pipeline -- //

  generate
    genvar ii;
    for (ii = 0; ii < LENGTH; ii += 1) begin : g_pipe_regs

      // Registered 2:1 MUX forming each daisy-chain element
      always @(posedge clock) begin
        if (reset) begin
          tvalid_q[ii] <= 1'b0;
          tlast_q[ii] <= 1'b0;
          tkeep_q[ii*KEEPS+KSB:ii*KEEPS] <= JUCKS;
          tdata_q[ii*WIDTH+MSB:ii*WIDTH] <= YUCKS;
        end else begin
          if (par_tvalid_i[ii]) begin
            // Push data onto chain from input source
            tvalid_q[ii] <= 1'b1;
            tlast_q[ii] <= par_tlast_i[ii];
            tkeep_q[ii*KEEPS+KSB:ii*KEEPS] <= par_tkeep_i[ii*KEEPS+KSB:ii*KEEPS];
            tdata_q[ii*WIDTH+MSB:ii*WIDTH] <= par_tdata_i[ii*WIDTH+MSB:ii*WIDTH];
          end else begin
            // Forward data from upstream to downstream
            tvalid_q[ii] <= src_tvalid_w[ii];
            tlast_q[ii] <= src_tlast_w[ii];  // FIXME: find end-of-packet !!
            tkeep_q[ii*KEEPS+KSB:ii*KEEPS] <= src_tkeep_w[ii*KEEPS+KSB:ii*KEEPS];
            tdata_q[ii*WIDTH+MSB:ii*WIDTH] <= src_tdata_w[ii*WIDTH+MSB:ii*WIDTH];
          end
        end
      end

    end  // g_pipe_regs
  endgenerate

endmodule  /* daisy_chain */
