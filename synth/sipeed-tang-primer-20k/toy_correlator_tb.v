`timescale 1ns / 100ps
module toy_correlator_tb;

  reg sig_clk = 1'b1;
  reg bus_clk = 1'b1;
  reg vis_clk = 1'b1;
  reg rst_n;

  always #15 sig_clk <= ~sig_clk;
  always #5 bus_clk <= ~bus_clk;
  always #1 vis_clk <= ~vis_clk;

  // -- Generate some data, and read it out -- //

  reg start = 1'b0;
  reg done = 1'b0;

  reg a_vld, a_lst;
  wire a_rdy;

  initial begin
    $dumpfile("../vcd/toy_correlator_tb.vcd");
    $dumpvars;

    #20 rst_n <= 1'b0;
    #90 rst_n <= 1'b1;

    #30 start <= 1'b1;
    while (!a_rdy || !a_vld) #30;

    #30 start <= 1'b0;

    while (!done) #10;

    #90 $finish;
  end

  initial begin
    #15000 $finish;
  end

  // -- Send random data to the A port -- //

  reg  [9:0] count;
  wire [9:0] cnext = count + 1;

  reg  [7:0] a_dat;

  always @(posedge a_clk) begin
    if (!rst_n) begin
      count <= 10'd0000;
      a_vld <= 1'b0;
      a_lst <= 1'b0;
    end else begin
      if (a_vld && a_rdy && a_lst) begin
        a_vld <= 1'b0;
        a_lst <= 1'b0;
        count <= 10'd0000;
      end else if (start && a_rdy) begin
        a_vld <= 1'b1;
        a_dat <= $urandom;
        count <= cnext;
      end else if (a_vld && a_rdy) begin
        a_dat <= $urandom;
        count <= cnext;

        if (cnext == 10'd0100) begin
          a_lst <= 1'b1;
        end
      end
    end
  end


  // -- Module Under Test -- //

  wire vis_start, vis_frame;
  wire b_vld, b_rdy, b_lst;
  wire [31:0] r_dat, i_dat;

  assign a_rdy = start | a_vld;
  assign b_rdy = 1'b1;

  toy_correlator #(
      .WIDTH(4),
      .MUX_N(4),
      .TRATE(15),
      .LOOP0(3),
      .LOOP1(5),
      .ACCUM(32),
      .SBITS(7)
  ) tart_correlator_inst (
      .sig_clock(sig_clk),
      .bus_clock(bus_clk),
      .bus_rst_n(rst_n),

      .vis_clock(vis_clk),
      .vis_rst_n(rst_n),

      .sig_valid_i(a_vld),
      .sig_last_i (a_lst),
      .sig_idata_i(a_dat[7:4]),
      .sig_qdata_i(a_dat[3:0]),

      .vis_start_o(vis_start),
      .vis_frame_o(vis_frame),

      .bus_revis_o(r_dat),
      .bus_imvis_o(i_dat),
      .bus_valid_o(b_vld),
      .bus_ready_i(b_rdy),
      .bus_last_o (b_lst)
  );


endmodule  // toy_correlator_tb
