`timescale 1ns / 100ps
module sigbuffer_tb;

  localparam integer WIDTH = 4;  // 4x antennas
  localparam integer MSB = WIDTH - 1;

  localparam integer TRATE = 5;  // 5x clock multiplier
  localparam integer TBITS = 3;
  localparam integer TSB = TBITS - 1;

  localparam integer LOOP0 = 3;  // Stage-1 loop count
  localparam integer LOOP1 = 5;  // Stage-2 loop count
  localparam integer COUNT = LOOP0 * LOOP1;
  localparam integer CBITS = 4;  // Bit-width of loop counter
  localparam integer CSB = CBITS - 1;

  localparam integer BBITS = 1;  // Number of banks of signal data
  localparam integer ABITS = BBITS + CBITS;  // Address width for signal SRAM
  localparam integer ASB = ABITS - 1;

  reg sig_clk = 1'b1;
  reg vis_clk = 1'b1;
  reg reset_n = 1'bx;

  always #5 vis_clk <= ~vis_clk;
  always #25 sig_clk <= ~sig_clk;

  reg start = 1'b0;
  reg ended = 1'b0;
  reg done = 1'b1;

  initial begin
    $dumpfile("../vcd/sigbuffer_tb.vcd");
    $dumpvars;

    #15 reset_n <= 1'b0;
    #60 reset_n <= 1'b1;

    #20 start <= 1'b1;
    #10 start <= 1'b0;

    #10 while (!ended) #10;

    #80 $finish;
  end

  // Safety-valve
  initial #6000 $finish;

  // -- Generate fake data -- //

  reg vld_r;
  reg fst_r;
  reg lst_r;
  reg [MSB:0] i_dat, q_dat;

  reg [ASB:0] count;

  wire [ASB:0] cnext = count + 1;
  wire cwrap = cnext[CSB:0] == COUNT[CSB:0];
  wire clast = cnext[CSB:0] == COUNT[CSB:0] - 1;
  wire [ASB:CBITS] cbank = count[ASB:CBITS] + 1;
  wire go_w = start || !done;

  // Fills two banks with (fake) signal data
  always @(posedge sig_clk) begin
    if (!reset_n) begin
      vld_r <= 1'b0;
      fst_r <= 1'b0;
      lst_r <= 1'b0;
      count <= {ABITS{1'b0}};
      done  <= 1'b1;
    end else begin
      // Start/stop logic for the fake data
      if (start) begin
        done <= 1'b0;
      end else if (count[ASB] && clast) begin
        done <= 1'b1;
      end

      // Address/counter
      if (vld_r) begin
        if (cwrap) begin
          count <= {cbank, {CBITS{1'b0}}};
        end else begin
          count <= cnext;
        end
      end

      // Interleaved, source partial-visibilities and their control signals
      vld_r <= go_w;
      if (start) begin
        fst_r <= 1'b1;
      end else begin
        fst_r <= cwrap && !done && !count[ASB];  // 1'b0;
      end
      lst_r <= clast && !done;

      if (go_w) begin
        {i_dat, q_dat} <= $urandom;
      end else begin
        {i_dat, q_dat} <= {WIDTH{2'bxx}};
      end
    end
  end

  // Finishing criteria
  reg frame;

  always @(posedge vis_clk) begin
    if (!reset_n) begin
      frame <= 1'b0;
      ended <= 1'b0;
    end else begin
      frame <= vld_w;

      if (done && frame && !vld_w) begin
        ended <= 1'b1;
      end else begin
        ended <= 1'b0;
      end

    end
  end


  // -- Module Under Test -- //

  wire vld_w, fst_w, lst_w;
  wire [TSB:0] adr_w;
  wire [MSB:0] i_sig, q_sig;

  sigbuffer #(
      .WIDTH(WIDTH),
      .TRATE(TRATE),
      .TBITS(TBITS),
      .COUNT(COUNT),
      .CBITS(CBITS),
      .BBITS(BBITS)
  ) SIGBUF0 (
      .sig_clk(sig_clk),
      .vis_clk(vis_clk),
      .reset_n(reset_n),
      // Antenna/source signals
      .valid_i(vld_r),
      .idata_i(i_dat),
      .qdata_i(q_dat),
      // Delayed, up-rated, looped signals
      .valid_o(vld_w),
      .first_o(fst_w),
      .last_o (lst_w),
      .taddr_o(adr_w),
      .idata_o(i_sig),
      .qdata_o(q_sig)
  );

endmodule  // sigbuffer_tb
