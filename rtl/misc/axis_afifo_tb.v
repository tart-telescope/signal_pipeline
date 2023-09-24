`timescale 1ns / 100ps
module axis_afifo_tb;

  reg a_clk = 1'b1;
  reg b_clk = 1'b1;
  reg c_clk = 1'b1;
  reg rst_n;

  always #3.5 a_clk <= ~a_clk;
  always #5.0 b_clk <= ~b_clk;
  always #2.5 c_clk <= ~c_clk;

  // -- Generate some data, and read it out -- //

  reg start = 1'b0;
  reg done = 1'b0;

  reg a_vld, a_lst;
  wire a_rdy;

  initial begin
    $dumpfile("../vcd/axis_afifo_tb.vcd");
    $dumpvars;

    #7.3 rst_n <= 1'b0;
    #101 rst_n <= 1'b1;

    #6.7 start <= 1'b1;
    while (!a_rdy || !a_vld) #7.0;

    #7.0 start <= 1'b0;

    while (!done) #10;

    #20 $finish;
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

  // -- Read data from the B port -- //

  reg b_rdy;
  wire b_vld, b_lst;
  wire [7:0] b_dat;

  always @(posedge b_clk) begin
    if (!rst_n) begin
      b_rdy <= 1'b0;
      done  <= 1'b0;
    end else begin
      if (b_vld && b_rdy && b_lst) begin
        b_rdy <= 1'b0;
        done  <= 1'b1;
      end else if (b_vld) begin
        b_rdy <= 1'b1;
      end
    end
  end

  // -- Module Under Test -- //

  axis_afifo #(
      .WIDTH(8),
      .ABITS(3)
  ) axis_afifo_inst (
      .s_aresetn(rst_n),

      .s_aclk(a_clk),
      .s_tvalid_i(a_vld),
      .s_tready_o(a_rdy),
      .s_tlast_i(a_lst),
      .s_tdata_i(a_dat),

      .m_aclk(b_clk),
      .m_tvalid_o(b_vld),
      .m_tready_i(b_rdy),
      .m_tlast_o(b_lst),
      .m_tdata_o(b_dat)
  );

  wire c_vld, c_rdy, c_lst, x_rdy;
  wire [7:0] c_dat;

  assign c_rdy = c_vld;

  axis_afifo #(
      .WIDTH(8),
      .ABITS(4)
  ) axis_afifo_tsni (
      .s_aresetn(rst_n),

      .s_aclk(a_clk),
      .s_tvalid_i(a_vld & a_rdy & x_rdy),
      .s_tready_o(x_rdy),
      .s_tlast_i(a_lst),
      .s_tdata_i(a_dat),

      .m_aclk(c_clk),
      .m_tvalid_o(c_vld),
      .m_tready_i(c_rdy),
      .m_tlast_o(c_lst),
      .m_tdata_o(c_dat)
  );

endmodule  // axis_afifo_tb
