`timescale 1ns / 100ps
module gw2a_oddr_tbuf (  /*AUTOARG*/);

  parameter CLOCK_POLARITY = 1'b0;
  parameter INIT = 1'b0;
  parameter [6:0] STATIC_DELAY = 7'h00;


  input clock;

  input dynamic_delay_i;
  input adjust_reverse_i;
  input adjust_step_i;
  output delay_overflow_o;

  input d0_i;
  input d1_i;
  input t_ni;

  output q_o;


  wire sig_e, sig_p, sig_n, sig_d, sig_oe_n;


  ODDR #(
      .TXCLK_POL(CLOCK_POLARITY),
      .INIT(INIT)
  ) sig_oddr_inst (
      .CLK(clock),
      .TX (t_ni),
      .D0 (d0_i),
      .D1 (d1_i),
      .Q0 (sig_d),
      .Q1 (sig_t)
  );


  IODELAY #(
      .C_STATIC_DLY(STATIC_DELAY)
  ) sig_iodelay_inst (
      .SDTAP(dynamic_delay_i),
      .SETN(adjust_reverse_i),
      .VALUE(adjust_step_i),
      .DF(delay_overflow_o),
      .DI(sig_d),
      .DO(sig_x)
  );


  TBUF sig_tbuf_inst (
      .I  (sig_x),
      .OEN(sig_t),
      .O  (q_o)
  );


endmodule  // gw2a_oddr_tbuf
