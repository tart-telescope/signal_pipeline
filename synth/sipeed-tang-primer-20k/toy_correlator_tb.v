`timescale 1ns / 100ps
module toy_correlator_tb;

  reg sig_clk = 1'b1;
  reg bus_clk = 1'b1;
  reg vis_clk = 1'b1;
  reg rst_n;

  always #30 sig_clk <= ~sig_clk;
  always #5 bus_clk <= ~bus_clk;
  always #2 vis_clk <= ~vis_clk;

  // -- Generate some data, and read it out -- //

  reg start = 1'b0;
  reg done = 1'b0;

  reg a_vld, a_lst;
  wire a_rdy;

  initial begin
    $dumpfile("toy_correlator_tb.vcd");
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


  //
  //  Fake Radios
  ///
  localparam USE_DUMMY_RADIOS = 1;
  localparam ANTENNA_NUM = 4;
  localparam NSB = ANTENNA_NUM - 1;
  localparam NZERO = {ANTENNA_NUM{1'b0}};

  reg [NSB:0] dat_i = NZERO, dat_q = NZERO;
  wire [NSB:0] sig_i, sig_q;

  genvar ant;
  generate
    for (ant = 0; ant < ANTENNA_NUM; ant = ant + 1) begin
      radio_dummy #(
          .ANT_NUM(ant)
      ) r0 (
          .clk16(sig_clk),
          .rst_n(rst_n),
          .i1(dat_i[ant]),
          .q1(dat_q[ant]),
          .data_i(sig_i[ant]),
          .data_q(sig_q[ant])
      );
    end
  endgenerate

  always @(posedge sig_clk) begin
    if (!rst_n) begin
      dat_i <= NZERO;
      dat_q <= NZERO;
    end else begin
      dat_i <= sig_i;
      dat_q <= sig_q;
    end
  end


  // -- Send random data to the A port -- //

  reg  [9:0] count;
  wire [9:0] cnext = count + 1;

  reg  [7:0] a_dat;

  always @(posedge sig_clk) begin
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
        a_dat <= USE_DUMMY_RADIOS ? {dat_i, dat_q} : $urandom;
        count <= cnext;
      end else if (a_vld && a_rdy) begin
        a_dat <= USE_DUMMY_RADIOS ? {dat_i, dat_q} : $urandom;
        count <= cnext;

        if (cnext == 10'd0104) begin
          a_lst <= 1'b1;
        end
      end
    end
  end


  // -- Module Under Test -- //

  wire vis_start, vis_frame;
  wire b_vld, b_lst;
  wire [31:0] r_dat, i_dat;

  assign a_rdy = start | a_vld;
  // assign b_rdy = 1'b1;

  reg b_rdy;

  always @(posedge bus_clk) begin
    if (!rst_n) begin
      b_rdy <= 1'b0;
    end else begin
      if (b_vld) begin
        b_rdy <= 1'b1;
      end else if (b_vld && b_rdy && b_lst) begin
        b_rdy <= 1'b0;
      end
      // b_rdy <= b_vld && !b_rdy;
    end
  end


  toy_correlator #(
      .WIDTH(ANTENNA_NUM),
      .MUX_N(4),
      .TRATE(15),
      .LOOP0(3),
      .LOOP1(5),
      .ACCUM(32),
      .SBITS(7)
  ) toy_correlator_inst (
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
