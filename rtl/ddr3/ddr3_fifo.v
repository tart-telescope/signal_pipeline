`timescale 1ns / 100ps
//-----------------------------------------------------------------
//              Lightweight DDR3 Memory Controller
//                            V0.5
//                     Ultra-Embedded.com
//                     Copyright 2020-21
//
//                   admin@ultra-embedded.com
//
//                     License: Apache 2.0
//-----------------------------------------------------------------
// Copyright 2020-21 Ultra-Embedded.com
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------

//
// TODO:
//  - uses combinational logic for the status flags, so low-perf?
//  - extra 'count' not required, either?
//  - replace 'ddr3_fifo' and 'ddr3_dfi_fifo' with a single core
//

module ddr3_fifo

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
    parameter WIDTH  = 8,
    parameter DEPTH  = 4,
    parameter ADDR_W = 2
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
      input             clk_i
    , input             rst_i
    , input [WIDTH-1:0] data_in_i
    , input             push_i
    , input             pop_i

    // Outputs
    , output [WIDTH-1:0] data_out_o
    , output             accept_o
    , output             valid_o
);

  //-----------------------------------------------------------------
  // Local Params
  //-----------------------------------------------------------------
  localparam COUNT_W = ADDR_W + 1;

  //-----------------------------------------------------------------
  // Registers
  //-----------------------------------------------------------------
  reg [  WIDTH-1:0] ram    [DEPTH-1:0];
  reg [ ADDR_W-1:0] rd_ptr;
  reg [ ADDR_W-1:0] wr_ptr;
  reg [COUNT_W-1:0] count;

  //-----------------------------------------------------------------
  // Sequential
  //-----------------------------------------------------------------
  always @(posedge clk_i)
    if (rst_i) begin
      count  <= {(COUNT_W) {1'b0}};
      rd_ptr <= {(ADDR_W) {1'b0}};
      wr_ptr <= {(ADDR_W) {1'b0}};
    end else begin
      // Push
      if (push_i & accept_o) begin
        ram[wr_ptr] <= data_in_i;
        wr_ptr      <= wr_ptr + 1;
      end

      // Pop
      if (pop_i & valid_o) rd_ptr <= rd_ptr + 1;

      // Count up
      if ((push_i & accept_o) & ~(pop_i & valid_o)) count <= count + 1;
      // Count down
      else if (~(push_i & accept_o) & (pop_i & valid_o)) count <= count - 1;
    end

  //-------------------------------------------------------------------
  // Combinatorial
  //-------------------------------------------------------------------
  /* verilator lint_off WIDTH */
  assign accept_o   = (count != DEPTH);
  assign valid_o    = (count != 0);
  /* verilator lint_on WIDTH */

  assign data_out_o = ram[rd_ptr];


endmodule  // ddr3_fifo


//-----------------------------------------------------------------
// FIFO
//-----------------------------------------------------------------
module ddr3_dfi_fifo

//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
    parameter WIDTH  = 144,
    parameter DEPTH  = 2,
    parameter ADDR_W = 1
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
      input             clk_i
    , input             rst_i
    , input [WIDTH-1:0] data_in_i
    , input             push_i
    , input             pop_i

    // Outputs
    , output [WIDTH-1:0] data_out_o
    , output             accept_o
    , output             valid_o
);

  //-----------------------------------------------------------------
  // Local Params
  //-----------------------------------------------------------------
  localparam COUNT_W = ADDR_W + 1;

  //-----------------------------------------------------------------
  // Registers
  //-----------------------------------------------------------------
  reg [  WIDTH-1:0] ram    [DEPTH-1:0];
  reg [ ADDR_W-1:0] rd_ptr;
  reg [ ADDR_W-1:0] wr_ptr;
  reg [COUNT_W-1:0] count;

  //-----------------------------------------------------------------
  // Sequential
  //-----------------------------------------------------------------
  always @(posedge clk_i)
    if (rst_i) begin
      count  <= {(COUNT_W) {1'b0}};
      rd_ptr <= {(ADDR_W) {1'b0}};
      wr_ptr <= {(ADDR_W) {1'b0}};
    end else begin
      // Push
      if (push_i & accept_o) begin
        ram[wr_ptr] <= data_in_i;
        wr_ptr      <= wr_ptr + 1;
      end

      // Pop
      if (pop_i & valid_o) rd_ptr <= rd_ptr + 1;

      // Count up
      if ((push_i & accept_o) & ~(pop_i & valid_o)) count <= count + 1;
      // Count down
      else if (~(push_i & accept_o) & (pop_i & valid_o)) count <= count - 1;
    end

  //-------------------------------------------------------------------
  // Combinatorial
  //-------------------------------------------------------------------
  /* verilator lint_off WIDTH */
  assign accept_o   = (count != DEPTH);
  assign valid_o    = (count != 0);
  /* verilator lint_on WIDTH */

  assign data_out_o = ram[rd_ptr];


endmodule  // ddr3_dfi_fifo
