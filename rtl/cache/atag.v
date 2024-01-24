`timescale 1ns / 100ps
module atag(/*AUTOARG*/);

// Number of "ways" (or tag-banks) for each (index subrange of an) address
parameter NWAYS = 4;
localparam NSB = NWAYS - 1;
localparam WBITS = $clog2(NWAYS);
localparam WSB = WBITS - 1;

// Cache tag-memory index bits (lower part of address)
parameter IBITS = 8;
localparam ISB = IBITS - 1;
localparam ISIZE = 1 << IBITS;

// Tag size bits (upper part of address)
parameter TBITS = 18;
localparam TSB = TBITS - 1;

// Total _cacheline_ address width/bits
localparam ADDRS = TBITS + IBITS;
localparam ASB = ADDRS - 1;


input clock;
input reset;

input find_i;
input [ASB:0] addr_i;
output [NSB:0] hits_o;
output [NSB:0] free_o;
output miss_o;

// todo: update and "dirty" ports

input store_i;
input evict_i;
input dirty_i;
input [NSB:0] way_i;
input [ISB:0] idx_i;
input [TSB:0] tag_i;


reg [NSB:0] hits, free;
reg find_q;
wire [TSB:0] tag;
wire [ISB:0] idx;


assign {tag, idx} = addr_i;

assign hits_o = {NWAYS{find_q}} & hits;
assign free_o = {NWAYS{find_q}} & free;
assign miss_o = find_q & ~(|hits);


always @(posedge clock) begin
  if (reset) begin
    find_q <= 1'b0;
  end else begin
    find_q <= find_i;
  end
end


// -- Tag Banks -- //

genvar ii;
generate
  for (ii=0; ii<NWAYS; ii=ii+1) begin : g_tagbanks

  reg [TSB:0] tsram [0:ISIZE-1];
  reg [ISIZE-1:0] empty;
  reg [ISIZE-1:0] dirty;

  wire [TSB:0] tag_w = tsram[idx];
  wire hit_w = find_i && !empty[idx] && !dirty[idx] && tag_w == tag;

    always @(posedge clock) begin
      if (reset) begin
        hits[ii] <= 1'b0;
        free[ii] <= 1'b1;
        empty <= {ISIZE{1'b0}};
        dirty <= {ISIZE{1'b0}};
      end else begin
        hits[ii] <= hit_w;
        free[ii] <= empty[idx];

        if (way_i[ii]) begin
          if (store_i) begin
            empty[idx_i] <= 1'b0;
            dirty[idx_i] <= 1'b0;
            tsram[idx_i] <= tag_i;
          end else if (evict_i) begin
            empty[idx_i] <= 1'b1;
            dirty[idx_i] <= 1'b0;
            tsram[idx_i] <= {TBITS{1'bx}};
          end else if (dirty_i) begin
            empty[idx_i] <= 1'b0;
            dirty[idx_i] <= 1'b1;
          end
        end
        
      end
    end
    
  end // g_tagbanks
endgenerate


endmodule // atag
