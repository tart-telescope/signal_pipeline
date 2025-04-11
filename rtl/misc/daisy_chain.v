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
    parameter integer LENGTH = 3,
    parameter integer LSB = LENGTH - 1,
    parameter integer WIDTH = 7,
    localparam integer MSB = WIDTH - 1,
    localparam integer WBITS = LENGTH * WIDTH,
    localparam integer WSB = WBITS - 1,
    localparam integer PBITS = WBITS - LENGTH,
    localparam integer PSB = PBITS - 1
) (
    // From (parallel) outputs of correlators
    input [LSB:0] par_tvalid_i,
   output [LSB:0] par_tready_o, // todo: not really possible !?
   input [LSB:0] par_tlast_i,
   input [KSB:0] par_tkeep_i, // todo: juice not worth the squeeze !?
    input [WSB:0] par_tdata_i,

    // Daisy-chain outputs
    output seq_tvalid_o,
   input seq_tready_i,
   output seq_tlast_o,
    output [KSB:0] seq_tkeep_o,
    output [MSB:0] seq_tdata_o
);

  // -- State & Signals -- //

  reg [LSB:0] valid;
  reg [WSB:0] tdata;
  wire [LSB:0] src_valid_w;
  wire [WSB:0] src_tdata_w;


  // -- Output Assignments -- //

  assign seq_valid_o = valid[LSB];
  assign seq_tdata_o = tdata[WSB:PBITS];

  // -- Internal Assignments -- //

  assign src_valid_w = {valid[LENGTH-2:0], 1'b0};  // Source valids
  assign src_tdata_w = {tdata[(LENGTH-1)*WIDTH-1:WIDTH], {WIDTH{1'bx}}};


  // -- Output select & pipeline -- //

  generate
    genvar ii;
    for (ii = 0; ii < LENGTH; ii += 1) begin : g_pipe_regs

      // Registered 2:1 MUX forming each daisy-chain element
      always @(posedge clock) begin
        if (reset) begin
          valid[ii] <= 1'b0;
          tdata[ii*WIDTH+MSB:ii*WIDTH] <= 'bx;
        end else begin
          if (par_valid_i[ii]) begin
            // Push data onto chain from input source
            valid[ii] <= 1'b1;
            tdata[ii*WIDTH+MSB:ii*WIDTH] <= par_tdata_i[ii*WIDTH+MSB:ii*WIDTH];
          end else begin
            // Forward data from upstream to downstream
            valid[ii] <= vld_w[ii];
            tdata[ii*WIDTH+MSB:ii*WIDTH] <= src_tdata_w[ii*WIDTH+MSB:ii*WIDTH];
          end
        end
      end

    end  // g_pipe_regs
  endgenerate


endmodule  /* daisy_chain */
