`timescale 1ns / 100ps
module ahbx_cache (/*AUTOARG*/);

input clock;
input reset;

input [2:0] hburst;
input hexcl;
input [2:0] hsize;
input [1:0] htrans;

input hwsel;
input hwlock;

input hwrite;
output hwresp;
input [ASB:0] hwaddr;
input [SSB:0] hwstrb;
input [MSB:0] hwdata;

input hrsel;
input hrlock;
output hready;
input [ASB:0] hraddr;
output [MSB:0] hrdata;


endmodule // ahbx_cache
