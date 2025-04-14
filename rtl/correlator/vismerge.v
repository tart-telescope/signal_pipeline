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
 *  - reverse-ordering of the chain;
 *
 */
module vismerge #(
    parameter integer LENGTH = 3,
    parameter integer LSB = LENGTH - 1,
    parameter integer WIDTH = 7,
    parameter integer REVERSE = 1,
    localparam integer MSB = WIDTH - 1,
    localparam integer WBITS = LENGTH * WIDTH,
    localparam integer WSB = WBITS - 1,
    localparam integer PBITS = WBITS - LENGTH,
    localparam integer PSB = PBITS - 1
) (
    input clock,
    input reset,

    // From (parallel) outputs of correlators
    input [LSB:0] par_valid_i,
    input [WSB:0] par_rdata_i,
    input [WSB:0] par_idata_i,

    // Daisy-chain outputs
    output seq_valid_o,
    output [MSB:0] seq_rdata_o,
    output [MSB:0] seq_idata_o
);

  // -- State & Signals -- //

  reg [LSB:0] valid;
  reg [WSB:0] rdata, idata;
  wire [LSB:0] src_valid_w, rev_valid_w;
  wire [WSB:0] src_rdata_w, src_idata_w;
  wire [WSB:0] rev_rdata_w, rev_idata_w;


  // -- Output Assignments -- //

  assign seq_valid_o = valid[LSB];
  assign seq_rdata_o = rdata[WSB:PBITS];
  assign seq_idata_o = idata[WSB:PBITS];

  // -- Internal Assignments -- //

  assign src_valid_w = {valid[LENGTH-2:0], 1'b0};  // Source valids
  assign src_rdata_w = {rdata[(LENGTH-1)*WIDTH-1:0], {WIDTH{1'bx}}};
  assign src_idata_w = {idata[(LENGTH-1)*WIDTH-1:0], {WIDTH{1'bx}}};
  // assign src_rdata_w = {rdata[(LENGTH-1)*WIDTH-1:WIDTH], {WIDTH{1'bx}}};
  // assign src_idata_w = {idata[(LENGTH-1)*WIDTH-1:WIDTH], {WIDTH{1'bx}}};

  assign rev_valid_w = {1'b0, valid[LENGTH-1:1]};  // Reversed valids
  assign rev_rdata_w = {{WIDTH{1'bx}}, rdata[LENGTH*WIDTH-1:WIDTH]};
  assign rev_idata_w = {{WIDTH{1'bx}}, idata[LENGTH*WIDTH-1:WIDTH]};


  // -- Output select & pipeline -- //

  generate
    genvar ii;
    for (ii = 0; ii < LENGTH; ii += 1) begin : g_pipe_regs

      // Registered 2:1 MUX forming each daisy-chain element
      always @(posedge clock) begin
        if (reset) begin
          valid[ii] <= 1'b0;
          rdata[ii*WIDTH+MSB:ii*WIDTH] <= {WIDTH{1'bx}};
          idata[ii*WIDTH+MSB:ii*WIDTH] <= {WIDTH{1'bx}};
        end else begin
          if (par_valid_i[ii]) begin
            // Push data onto chain from input source
            valid[ii] <= 1'b1;
            rdata[ii*WIDTH+MSB:ii*WIDTH] <= par_rdata_i[ii*WIDTH+MSB:ii*WIDTH];
            idata[ii*WIDTH+MSB:ii*WIDTH] <= par_idata_i[ii*WIDTH+MSB:ii*WIDTH];
          end else begin
            // Forward data from upstream to downstream
            valid[ii] <= REVERSE ? rev_valid_w[ii] : src_valid_w[ii];
            rdata[ii*WIDTH+MSB:ii*WIDTH] <= REVERSE ?
                                            rev_rdata_w[ii*WIDTH+MSB:ii*WIDTH] :
                                            src_rdata_w[ii*WIDTH+MSB:ii*WIDTH];
            idata[ii*WIDTH+MSB:ii*WIDTH] <= REVERSE ?
                                            rev_idata_w[ii*WIDTH+MSB:ii*WIDTH] :
                                            src_idata_w[ii*WIDTH+MSB:ii*WIDTH];
          end
        end
      end

    end  // g_pipe_regs
  endgenerate


endmodule  /* vismerge */
