`timescale 1ns / 100ps
module correlate (
    clock,
    reset_n,

    valid_i,
    first_i,
    last_i,
    auto_i,
    ai_i,
    aq_i,
    bi_i,
    bq_i,

    valid_o,
    re_o,
    im_o
);

  // Bit-width of local adders
  parameter integer WIDTH = 4;
  localparam integer MSB = WIDTH - 1;

  input clock;
  input reset_n;

  // AX4-Stream like interface, with no backpressure
  input valid_i;
  input first_i;
  input last_i;
  input auto_i; // todo: compute auto-correlations
  input ai_i;  // 4x data bits
  input aq_i;
  input bi_i;
  input bq_i;

  // AX4-Stream like interface, with no backpressure
  output valid_o;
  output [MSB:0] re_o;
  output [MSB:0] im_o;


  reg valid = 1'b0;
  reg [MSB:0] re_r = {WIDTH{1'b0}};
  reg [MSB:0] im_r = {WIDTH{1'b0}};

  assign valid_o = valid;
  assign re_o = re_r;
  assign im_o = im_r;


  wire [3:0] bits = {ai_i, aq_i, bi_i, bq_i};
  wire [1:0] re_w, im_w;

  // todo: auto-correlations
  wire re_inc = bits == 4'h0 || bits == 4'h5 || bits == 4'ha || bits == 4'hf;
  wire re_dec = bits == 4'h3 || bits == 4'h6 || bits == 4'h9 || bits == 4'hc;
  wire im_inc = bits == 4'h1 || bits == 4'h7 || bits == 4'h8 || bits == 4'he;
  wire im_dec = bits == 4'h2 || bits == 4'h4 || bits == 4'hb || bits == 4'hd;

  wire [1:0] xr_w = {re_inc, ~re_inc & ~re_dec};  // values in {0, 1, 2}
  wire [1:0] xi_w = {im_inc, ~im_inc & ~im_dec};

  /*
assign re_w[1] = bits == 4'h0 || bits == 4'h5 || bits == 4'ha || bits == 4'hf;
assign re_w[0] = bits == 4'h1 || bits == 4'h2 || bits == 4'h4 || bits == 4'h7 ||
                 bits == 4'h8 || bits == 4'hb || bits == 4'hd || bits == 4'he;

assign im_w[1] = bits == 4'h1 || bits == 4'h7 || bits == 4'h8 || bits == 4'he;
assign im_w[0] = bits == 4'h0 || bits == 4'h3 || bits == 4'h5 || bits == 4'h6 ||
                 bits == 4'h9 || bits == 4'ha || bits == 4'hc || bits == 4'hf;
*/

/*
  // todo: add pipeline registers between vis-calc and adders?
  // todo: should the pipeline registers between optional?
  always @(posedge clock) begin
    if (!reset_n) begin
      valid <= 1'b0;
    end else if (valid_i) begin
      if (first_i) begin
        re_r <= xr_w;
        im_r <= xi_w;
      end else begin
        re_r <= re_r + xr_w;
        im_r <= im_r + xi_w;
      end

      valid <= last_i;
    end else begin
      valid <= 1'b0;
    end
  end
*/

  // 2-stage cross-correlation then accumulate.
  reg [1:0] xr_r, xi_r;
  reg vld_r, fst_r, lst_r;

  always @(posedge clock) begin
    if (!reset_n) begin
      vld_r <= 1'b0;
      fst_r <= 1'b0;
      lst_r <= 1'b0;
    end else begin
      // Pipeline registers
      vld_r <= valid_i;
      fst_r <= first_i;
      lst_r <= last_i;

      if (valid_i) begin
        xr_r <= xr_w;
        xi_r <= xi_w;
      end

      if (vld_r) begin
        if (fst_r) begin
          re_r <= xr_r;
          im_r <= xi_r;
        end else begin
          re_r <= re_r + xr_r;
          im_r <= im_r + xi_r;
        end

        valid <= lst_r;
      end else begin
        valid <= 1'b0;
      end
    end
  end

endmodule  // correlate
