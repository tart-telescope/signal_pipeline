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

  #800 $finish; // todo ...
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


reg arvalid, rready, accept, error, valid;
reg [3:0] arid;
reg [7:0] arlen;
reg [1:0] arburst;
reg [ASB:0] araddr;
reg [MSB:0] rdat;
reg [SSB:0] wstrb;
wire arready, rvalid, rlast, fetch, store;
wire [3:0] rid;
wire [1:0] rresp;
wire [ASB:0] maddr;
wire [SSB:0] mask;
wire [MSB:0] rdata, wdat;


// -- Initialisation -- //

reg [127:0] data;

initial begin : Stimulus
  @(posedge clock);

  while (reset) begin
    @(posedge clock);

    arvalid <= 1'b0;
    arid <= 0;
    araddr <= 0;
  end

  @(posedge clock);
  @(posedge clock);

  axi_read(0, data);
  $display("%10t: READ = %x", $time, data);

  #100 @(posedge clock);   
  $finish;
end


ddr3_axi_ctrl
#( .WIDTH(WIDTH),
   .MASKS(MASKS),
   .ADDRS(ADDRS)
) ddr3_axi_ctrl_inst
 (
    .clock(clock),
    .reset(reset),

    .axi_awvalid_i(1'b0),
    .axi_awready_o(),
    .axi_awaddr_i(),
    .axi_awid_i(),
    .axi_awlen_i(),
    .axi_awburst_i(),

    .axi_wvalid_i(1'b0),
    .axi_wready_o(),
    .axi_wlast_i(),
    .axi_wstrb_i(wstrb),
    .axi_wdata_i(),

    .axi_bvalid_o(),
    .axi_bready_i(1'b0),
    .axi_bresp_o(),
    .axi_bid_o(),

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

    .ram_wren_o(store),
    .ram_rden_o(fetch),
    .ram_req_id_o(),
    .ram_addr_o(maddr),
    .ram_wrmask_o(mask),
    .ram_wrdata_o(wdat),
    .ram_accept_i(accept),
    .ram_valid_i(valid),
    .ram_error_i(error),
    .ram_resp_id_i(),
    .ram_rddata_i(rdat)
);


// -- Fake SDRAM -- //

always @(posedge clock) begin
  if (reset) begin
    valid <= 1'b0;
    error <= 1'b0;
    accept <= 1'b0;
    rdat <= {WIDTH{1'bx}};
  end else begin
    accept <= 1'b1;

    if (fetch) begin
      valid <= 1'b1;
      rdat <= $urandom;
    end

    if (store) begin
      $display("Ignoring STORE");
    end
  end
end


//-----------------------------------------------------------------
// axi_read: Perform read transfer (128-bit)
//-----------------------------------------------------------------
task axi_read;
    input  [ASB:0] addr;
    output [127:0] data;
  begin
    arvalid <= 1'b1;
    arlen <= 128 / WIDTH - 1;
    arid <= arid + 1;
    arburst <= 2'b01; // INCR
    araddr <= addr;
    rready <= 1'b0;

    @(posedge clock);

    while (!arready) begin
        @(posedge clock);
    end
    arvalid <= 1'b0;
    rready <= 1'b1;
    
    @(posedge clock);

    while (!rvalid || !rlast) begin
      if (rvalid) begin
        data <= {rdata, data[127:WIDTH]};
      end

      @(posedge clock);
    end

    rready <= 1'b0;
    data <= {rdata, data[127:WIDTH]};
end
endtask


endmodule // ddr3_axi_ctrl_tb
