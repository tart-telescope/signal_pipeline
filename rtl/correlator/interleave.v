`timescale 1ns / 100ps
/**
 * FIFO for halving the width of a sparse/aperiodic data stream.
 */
module interleave #(
                    parameter integer WIDTH = 7,
                    localparam integer MSB = WIDTH - 1,
                    parameter integer DEPTH = 32,
                    localparam integer ABITS = $clog2(DEPTH),
                    localparam integer ASB = ABITS - 1
                    )
  (
   input clock,
   input reset,

   input s_tvalid,
   input [WIDTH+MSB:0] s_tdata,

   output m_tvalid,
   output [MSB:0] m_tdata
   );


endmodule /* interleave */
