`timescale 1ns / 100ps
module viscalc (
    clock_i,
    reset_ni,

    valid_i,
    first_i,
    last_i,
    ai_i,
    aq_i,
    bi_i,
    bq_i,

    valid_o,
    last_o,
    re_o,
    im_o
);

  parameter integer WIDTH = 4;
  localparam integer MSB = WIDTH - 1;

  input clock_i;
  input reset_ni;

  // AX4-Stream like interface, with no backpressure
  input valid_i;
  input first_i;
  input last_i;
  input ai_i;  // 4x data bits
  input aq_i;
  input bi_i;
  input bq_i;

  // AX4-Stream like interface, with no backpressure
  output valid_o;
  output last_o;
  output [MSB:0] re_o;
  output [MSB:0] im_o;


  reg valid = 1'b0;
  reg [MSB:0] re_r = {WIDTH{1'b0}};
  reg [MSB:0] im_r = {WIDTH{1'b0}};

  assign valid_o = valid;
  assign last_o = valid;
  assign re_o = re_r;
  assign im_o = im_r;


  wire [3:0] bits = {ai_i, aq_i, bi_i, bq_i};
  wire [1:0] re_w, im_w;

  wire re_inc = bits == 4'h0 || bits == 4'h5 || bits == 4'ha || bits == 4'hf;
  wire re_dec = bits == 4'h3 || bits == 4'h6 || bits == 4'h9 || bits == 4'hc;
  wire im_inc = bits == 4'h1 || bits == 4'h7 || bits == 4'h8 || bits == 4'he;
  wire im_dec = bits == 4'h2 || bits == 4'h4 || bits == 4'hb || bits == 4'hd;

  wire [1:0] vr_w = {re_inc, ~re_inc & ~re_dec};  // values in {0, 1, 2}
  wire [1:0] vi_w = {im_inc, ~im_inc & ~im_dec};

  /*
assign re_w[1] = bits == 4'h0 || bits == 4'h5 || bits == 4'ha || bits == 4'hf;
assign re_w[0] = bits == 4'h1 || bits == 4'h2 || bits == 4'h4 || bits == 4'h7 ||
                 bits == 4'h8 || bits == 4'hb || bits == 4'hd || bits == 4'he;

assign im_w[1] = bits == 4'h1 || bits == 4'h7 || bits == 4'h8 || bits == 4'he;
assign im_w[0] = bits == 4'h0 || bits == 4'h3 || bits == 4'h5 || bits == 4'h6 ||
                 bits == 4'h9 || bits == 4'ha || bits == 4'hc || bits == 4'hf;
*/

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

endmodule  // viscalc
