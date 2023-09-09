`timescale 1ns / 100ps
module visaccum (
    clock_i,
    reset_ni,

    valid_i,
    first_i,
    last_i,
    re_i,
    im_i,
    bi_i,
    bq_i,

    valid_o,
    last_o,
    re_o,
    im_o
);

  parameter integer IBITS = 4;
  parameter integer OBITS = 7;
  parameter integer PSUMS = 8;

  localparam integer ISB = IBITS - 1;
  localparam integer OSB = OBITS - 1;

  input clock_i;
  input reset_ni;

  // AX4-Stream like interface, but with no backpressure
  input valid_i;
  input first_i;
  input last_i;
  input [ISB:0] re_i;
  input [ISB:0] im_i;

  // AX4-Stream like interface, but with no backpressure
  output valid_o;
  output last_o;
  output [OSB:0] re_o;
  output [OSB:0] im_o;


  reg valid = 1'b0;
  reg [OSB:0] re_r = {OBITS{1'b0}};
  reg [OSB:0] im_r = {OBITS{1'b0}};

  reg [OSB:0] rsram[PSUMS];
  reg [OSB:0] isram[PSUMS];

  assign valid_o = valid;
  assign last_o = valid;
  assign re_o = re_r;
  assign im_o = im_r;

  always @(posedge clock_i) begin
    if (!reset_ni) begin
      valid <= 1'b0;
    end else if (valid_i) begin
      if (first_i) begin
        re_r <= vr_w;
        im_r <= vi_w;
      end else begin
        re_r <= re_r + vr_w;
        im_r <= im_r + vi_w;
      end

      valid <= last_i;
    end else begin
      valid <= 1'b0;
    end
  end

endmodule  // visaccum
