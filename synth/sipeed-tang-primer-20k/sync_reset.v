`timescale 1ns / 100ps
module
  sync_reset #(
      parameter integer N = 3
  ) (
      input clock, // New clock domain for reset
      input arst_n, // Asynchronous reset to synchronise
      output reset
  );

// Todo:
//  - clean this up;

localparam integer MSB = N - 1;
localparam integer RZERO = {N{1'b0}};
localparam integer RONES = {N{1'b1}};
localparam integer RUNIT = {{MSB{1'b0}}, 1'b1};

reg                [MSB:0] reset_count, reset_delay;

assign reset = ~reset_count[MSB];

// Cross clock-domains
always @(posedge clock or negedge arst_n) begin
    if (!arst_n) begin
        reset_delay <= RZERO;
    end else begin
        reset_delay <= {reset_delay[N-2:0], arst_n};
    end
end

  // Reset after some more delays
  always @(posedge clock) begin
    if (!reset_delay[MSB]) begin
        reset_count <= RZERO;
    end else if (!reset_count[MSB]) begin
        reset_count <= reset_count + RUNIT;
    end
  end


endmodule  // sync_reset
