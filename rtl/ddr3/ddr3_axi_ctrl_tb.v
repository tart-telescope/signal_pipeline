`timescale 1ns / 100ps
module ddr3_axi_ctrl_tb;

  // -- Simulation Settings -- //

  parameter ADDRS = 32;
  localparam ASB = ADDRS - 1;

  parameter WIDTH = 32;
  localparam MSB = WIDTH - 1;

  parameter MASKS = WIDTH / 8;
  localparam SSB = MASKS - 1;


  // -- Simulation Data -- //

  initial begin
    $dumpfile("ddr3_axi_ctrl_tb.vcd");
    $dumpvars(0, ddr3_axi_ctrl_tb);

    #800 $finish;  // todo ...
  end


  // -- Globals -- //

  reg osc = 1'b1;
  reg ddr = 1'b1;
  reg rst = 1'b0;

  always #5.0 osc <= ~osc;
  always #2.5 ddr <= ~ddr;

  initial begin
    rst <= 1'b1;
    #200 rst <= 1'b0;
  end


  wire locked, clock, reset;
  wire clk_ddr, clk_ddr_dqs, clk_ref;


  assign clock = osc;
  assign reset = rst | ~locked;

  assign #50 locked = 1'b1;


  reg awvalid, wvalid, wlast, bready, arvalid, rready, accept, error, valid;
  reg [3:0] awid, arid;
  reg [7:0] awlen, arlen;
  reg [1:0] awburst, arburst;
  reg [ASB:0] awaddr, araddr;
  reg [MSB:0] rdat;
  reg [SSB:0] wstrb;
  wire awready, wready, bvalid, arready, rvalid, rlast, fetch, store;
  wire [3:0] bid, rid;
  wire [1:0] bresp, rresp;
  wire [ASB:0] maddr;
  wire [SSB:0] mask;
  wire [MSB:0] rdata, wdat;


  // -- Initialisation -- //

  reg [127:0] data;
reg [MSB:0] wdata;

  initial begin : Stimulus
    @(posedge clock);

    while (reset) begin
      @(posedge clock);

      awvalid <= 1'b0;
      wvalid <= 1'b0;
      wlast <= 1'b0;
      awid <= 0;
      awaddr <= 0;
      wstrb <= 0;
      bready <= 1'b1;

      arvalid <= 1'b0;
      arid <= 0;
      araddr <= 0;
    end

    @(posedge clock);
    @(posedge clock);
    data <= {$urandom, $urandom, $urandom, $urandom};

    @(posedge clock);

    axi_store(0, data);
    $display("%10t: WRITE = %x", $time, data);

    @(posedge clock);
    @(posedge clock);

    axi_fetch(0, data);
    $display("%10t: READ = %x", $time, data);

    #100 @(posedge clock);
    $finish;
  end


  // -- Module Under Test -- //

always @data begin
end

  ddr3_axi_ctrl #(
      .WIDTH(WIDTH),
      .MASKS(MASKS),
      .ADDRS(ADDRS)
  ) ddr3_axi_ctrl_inst (
      .clock(clock),
      .reset(reset),

      .axi_awvalid_i(awvalid),
      .axi_awready_o(awready),
      .axi_awaddr_i(awaddr),
      .axi_awid_i(awid),
      .axi_awlen_i(awlen),
      .axi_awburst_i(awburst),

      .axi_wvalid_i(wvalid),
      .axi_wready_o(wready),
      .axi_wlast_i (wlast),
      .axi_wstrb_i (wstrb),
      .axi_wdata_i (wdata),

      .axi_bvalid_o(bvalid),
      .axi_bready_i(bready),
      .axi_bresp_o(bresp),
      .axi_bid_o(bid),

      .axi_arvalid_i(arvalid),
      .axi_arready_o(arready),
      .axi_araddr_i(araddr),
      .axi_arid_i(arid),
      .axi_arlen_i(arlen),
      .axi_arburst_i(arburst),

      .axi_rvalid_o(rvalid),
      .axi_rready_i(rready),
      .axi_rlast_o(rlast),
      .axi_rresp_o(rresp),
      .axi_rid_o(rid),
      .axi_rdata_o(rdata),

      .mem_store_o(store),
      .mem_fetch_o(fetch),
      .mem_req_id_o(),
      .mem_addr_o(maddr),
      .mem_wrmask_o(mask),
      .mem_wrdata_o(wdat),
      .mem_accept_i(accept),
      .mem_valid_i(valid),
      .mem_error_i(error),
      .mem_resp_id_i(4'b0110),
      .mem_rddata_i(rdat)
  );


  // -- Fake SDRAM -- //

  always @(posedge clock) begin
    if (reset) begin
      valid  <= 1'b0;
      error  <= 1'b0;
      accept <= 1'b0;
      rdat   <= {WIDTH{1'bx}};
    end else begin
      accept <= 1'b1;

      if (fetch) begin
        valid <= 1'b1;
        rdat  <= $urandom;
      end

      if (store) begin
        $display("Ignoring STORE");
      end
    end
  end


  //-----------------------------------------------------------------
  // axi_store: Perform write transfer (128-bit)
  //-----------------------------------------------------------------
  task axi_store;
    input [ASB:0] addr;
    input [127:0] data;
    begin
      integer count;

      awvalid <= 1'b1;
      awlen <= 128 / WIDTH - 1;
      awid <= arid + 1;
      awburst <= 2'b01;  // INCR
      awaddr <= addr;
      wvalid <= 1'b0;
      count <= 0;

      @(posedge clock);

      while (!awready) begin
        @(posedge clock);
      end

      awvalid <= 1'b0;
      wvalid  <= 1'b1;
      wlast   <= 1'b0;
      wdata   <= data[MSB:0];
      data    <= {{WIDTH{1'bx}}, data[127:WIDTH]};
      count   <= 1;

      while (!wready || count < 4) begin
        if (wready) begin
          count <= count + 1;
          wlast <= count > 2;
          wdata <= data[MSB:0];
          data  <= {{WIDTH{1'bx}}, data[127:WIDTH]};
        end

        @(posedge clock);
      end

      wvalid <= 1'b0;
      wlast  <= 1'b0;
    end
  endtask  // axi_fetch


  //-----------------------------------------------------------------
  // axi_fetch: Perform read transfer (128-bit)
  //-----------------------------------------------------------------
  task axi_fetch;
    input [ASB:0] addr;
    output [127:0] data;
    begin
      arvalid <= 1'b1;
      arlen <= 128 / WIDTH - 1;
      arid <= arid + 1;
      arburst <= 2'b01;  // INCR
      araddr <= addr;
      rready <= 1'b0;

      @(posedge clock);

      while (!arready) begin
        @(posedge clock);
      end
      arvalid <= 1'b0;
      rready  <= 1'b1;

      @(posedge clock);

      while (!rvalid || !rlast) begin
        if (rvalid) begin
          data <= {rdata, data[127:WIDTH]};
        end

        @(posedge clock);
      end

      rready <= 1'b0;
      data   <= {rdata, data[127:WIDTH]};
    end
  endtask  // axi_fetch


endmodule  // ddr3_axi_ctrl_tb
