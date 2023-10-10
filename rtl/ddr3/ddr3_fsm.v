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

module ddr3_fsm (
    clock,
    reset,

    cfg_enable_i,
    cfg_stb_i,
    cfg_stall_o,
    cfg_data_i,

    mem_store_i,
    mem_fetch_i,
    mem_agree_o,
    mem_valid_o,
    mem_error_o,
    mem_reqid_i,
    mem_bresp_o,
    mem_taddr_i,
    mem_wmask_i,
    mem_wdata_i,
    mem_rdata_o,

    dfi_rddata_i,
    dfi_rddata_valid_i,
    dfi_rddata_dnv_i,
    dfi_address_o,
    dfi_bank_o,
    dfi_cas_n_o,
    dfi_cke_o,
    dfi_cs_n_o,
    dfi_odt_o,
    dfi_ras_n_o,
    dfi_reset_n_o,
    dfi_we_n_o,
    dfi_wrdata_o,
    dfi_wrdata_en_o,
    dfi_wrdata_mask_o,
    dfi_rddata_en_o
);

  parameter DDR_MHZ = 100;
  parameter DDR_WRITE_LATENCY = 6; // note: not 'CWL', but related
  parameter DDR_READ_LATENCY = 5; // note: not 'CL', but latency for this module

  parameter DDR_BANKS = 8;
localparam DDR_BBITS = $clog2(DDR_BANKS);
localparam BSB = DDR_BBITS - 1;

  parameter DDR_COL_W = 10;
  parameter DDR_ROW_W = 15;
  localparam ASB = DDR_ROW_W - 1;

  parameter DDR_BRC_MODE = 0;

  parameter TRAN_ID_WIDTH = 16;  // todo ...
  localparam TSB = TRAN_ID_WIDTH - 1;
  localparam TZERO = {TRAN_ID_WIDTH{1'b0}};


  input clock;
  input reset;

  input cfg_enable_i;
  input cfg_stb_i;
  output cfg_stall_o;
  input [31:0] cfg_data_i;

  input [15:0] mem_store_i;
  input mem_fetch_i;
  input [31:0] mem_addr_i;
  input [127:0] mem_wdata_i;
  input [TSB:0] mem_req_id_i;
  output mem_accept_o;
  output mem_ack_o;
  output mem_error_o;
  output [TSB:0] mem_resp_id_o;
  output [127:0] mem_rdata_o;

  input [31:0] dfi_rddata_i;
  input dfi_rddata_valid_i;
  input [1:0] dfi_rddata_dnv_i;
  output [14:0] dfi_address_o;
  output [2:0] dfi_bank_o;
  output dfi_cas_n_o;
  output dfi_cke_o;
  output dfi_cs_n_o;
  output dfi_odt_o;
  output dfi_ras_n_o;
  output dfi_reset_n_o;
  output dfi_we_n_o;
  output [31:0] dfi_wrdata_o;
  output dfi_wrdata_en_o;
  output [3:0] dfi_wrdata_mask_o;
  output dfi_rddata_en_o;


  //-----------------------------------------------------------------
  // Defines / Local params
  //-----------------------------------------------------------------
`ifdef XILINX_SIMULATOR
  localparam DDR_START_DELAY = 60000 / (1000 / DDR_MHZ);  // 60uS
`else
`ifdef __icarus
  localparam DDR_START_DELAY = 60000 / (1000 / DDR_MHZ);  // 60uS
`else
  localparam DDR_START_DELAY = 600000 / (1000 / DDR_MHZ);  // 600uS
`endif
`endif
  localparam DDR_REFRESH_CYCLES = (64000 * DDR_MHZ) / 8192;
  localparam DDR_BURST_LEN = 8;

  localparam CMD_W = 4;
  localparam CMD_NOP = 4'b0111;
  localparam CMD_ACTIVE = 4'b0011;
  localparam CMD_READ = 4'b0101;
  localparam CMD_WRITE = 4'b0100;
  localparam CMD_PRECHARGE = 4'b0010;
  localparam CMD_REFRESH = 4'b0001;
  localparam CMD_LOAD_MODE = 4'b0000;
  localparam CMD_ZQCL = 4'b0110;

  // Mode Configuration
  // - DLL disabled (low speed only)
  // - CL=6
  // - AL=0
  // - CWL=6
  localparam MR0_REG = 15'h0120;
  localparam MR1_REG = 15'h0001;
  localparam MR2_REG = 15'h0008;
  localparam MR3_REG = 15'h0000;

  // SM states
  localparam STATE_W = 4;
  localparam SSB = STATE_W - 1;
  localparam STATE_INIT = 4'd0;
  localparam STATE_DELAY = 4'd1;
  localparam STATE_IDLE = 4'd2;
  localparam STATE_ACTIVATE = 4'd3;
  localparam STATE_READ = 4'd4;
  localparam STATE_WRITE = 4'd5;
  localparam STATE_PRECHARGE = 4'd6;
  localparam STATE_REFRESH = 4'd7;

  localparam AUTO_PRECHARGE = 10;
  localparam ALL_BANKS = 10;


  //-----------------------------------------------------------------
  // External Interface
  //-----------------------------------------------------------------
  wire [ 31:0] ram_addr_w = mem_addr_i;
  wire [ 15:0] ram_wr_w = mem_store_i;
  wire         ram_rd_w = mem_fetch_i;
  wire         ram_accept_w;
  wire [127:0] ram_write_data_w = mem_wdata_i;
  wire [127:0] ram_read_data_w;
  wire         ram_ack_w;

  wire         id_fifo_space_w;
  wire         ram_req_w = ((ram_wr_w != TZERO) | ram_rd_w) && id_fifo_space_w;


  assign mem_ack_o       = ram_ack_w;
  assign mem_rdata_o = ram_read_data_w;
  assign mem_error_o     = 1'b0;
  assign mem_accept_o    = ram_accept_w;


  //-----------------------------------------------------------------
  // Registers / Wires
  //-----------------------------------------------------------------
  wire cmd_accept_w;

  wire sdram_rd_valid_w;
  wire [127:0] sdram_data_in_w;

  reg refresh_q;

  reg [BSB:0] row_open_q;
  reg [ASB:0] active_row_q[0:DDR_BANKS-1];

  reg [SSB:0] state_q;
  reg [SSB:0] next_state_r;
  reg [SSB:0] target_state_r;
  reg [SSB:0] target_state_q;

  // Address bits (RBC mode)
  wire [ASB:0] addr_col_w = {
    {(DDR_ROW_W - DDR_COL_W) {1'b0}}, ram_addr_w[DDR_COL_W:2], 1'b0
  };
  wire [ASB:0]  addr_row_w  = DDR_BRC_MODE ? ram_addr_w[DDR_ROW_W+DDR_COL_W:DDR_COL_W+1] :            // BRC
  ram_addr_w[DDR_ROW_W+DDR_COL_W+3:DDR_COL_W+3+1];  // RBC
  wire [BSB:0] addr_bank_w = DDR_BRC_MODE ? ram_addr_w[DDR_ROW_W+DDR_COL_W+3:DDR_ROW_W+DDR_COL_W+1]: // BRC
  ram_addr_w[DDR_COL_W+1+3-1:DDR_COL_W+1];  // RBC


  //-----------------------------------------------------------------
  // SDRAM State Machine
  //-----------------------------------------------------------------
  always @* begin
    next_state_r   = state_q;
    target_state_r = target_state_q;

    case (state_q)
      //-----------------------------------------
      // STATE_INIT
      //-----------------------------------------
      STATE_INIT: begin
        if (refresh_q) next_state_r = STATE_IDLE;
      end
      //-----------------------------------------
      // STATE_IDLE
      //-----------------------------------------
      STATE_IDLE: begin
        // Disabled
        if (!cfg_enable_i) next_state_r = STATE_IDLE;
        // Pending refresh
        // Note: tRAS (open row time) cannot be exceeded due to periodic
        //        auto refreshes.
        else if (refresh_q) begin
          // Close open rows, then refresh
          if (|row_open_q) next_state_r = STATE_PRECHARGE;
          else next_state_r = STATE_REFRESH;

          target_state_r = STATE_REFRESH;
        end  // Access request
        else if (ram_req_w) begin
          // Open row hit
          if (row_open_q[addr_bank_w] && addr_row_w == active_row_q[addr_bank_w]) begin
            if (!ram_rd_w) next_state_r = STATE_WRITE;
            else next_state_r = STATE_READ;
          end  // Row miss, close row, open new row
          else if (row_open_q[addr_bank_w]) begin
            next_state_r = STATE_PRECHARGE;

            if (!ram_rd_w) target_state_r = STATE_WRITE;
            else target_state_r = STATE_READ;
          end  // No open row, open row
          else begin
            next_state_r = STATE_ACTIVATE;

            if (!ram_rd_w) target_state_r = STATE_WRITE;
            else target_state_r = STATE_READ;
          end
        end
      end
      //-----------------------------------------
      // STATE_ACTIVATE
      //-----------------------------------------
      STATE_ACTIVATE: begin
        // Proceed to read or write state
        next_state_r = target_state_q;
      end
      //-----------------------------------------
      // STATE_READ
      //-----------------------------------------
      STATE_READ: begin
        next_state_r = STATE_IDLE;
      end
      //-----------------------------------------
      // STATE_WRITE
      //-----------------------------------------
      STATE_WRITE: begin
        next_state_r = STATE_IDLE;
      end
      //-----------------------------------------
      // STATE_PRECHARGE
      //-----------------------------------------
      STATE_PRECHARGE: begin
        // Closing row to perform refresh
        if (target_state_q == STATE_REFRESH) next_state_r = STATE_REFRESH;
        // Must be closing row to open another
        else
          next_state_r = STATE_ACTIVATE;
      end
      //-----------------------------------------
      // STATE_REFRESH
      //-----------------------------------------
      STATE_REFRESH: begin
        next_state_r = STATE_IDLE;
      end
      default: ;
    endcase
  end


  // Record target state
  always @(posedge clock) begin
    if (reset) begin
      target_state_q <= STATE_IDLE;
    end else if (cmd_accept_w) begin
      target_state_q <= target_state_r;
    end
  end

  // Update state
  always @(posedge clock) begin
    if (reset) begin
      state_q <= STATE_INIT;
    end else if (cmd_accept_w) begin
      state_q <= next_state_r;
    end
  end


  //-----------------------------------------------------------------
  // Refresh counter
  //-----------------------------------------------------------------
  localparam REFRESH_CNT_W = 20;

  reg [REFRESH_CNT_W-1:0] refresh_timer_q;

  always @(posedge clock) begin
    if (reset) begin
      refresh_timer_q <= DDR_START_DELAY;
    end else if (refresh_timer_q == {REFRESH_CNT_W{1'b0}}) begin
      refresh_timer_q <= DDR_REFRESH_CYCLES;
    end else begin
      refresh_timer_q <= refresh_timer_q - 1;
    end
  end

  always @(posedge clock) begin
    if (reset) begin
      refresh_q <= 1'b0;
    end else if (refresh_timer_q == {REFRESH_CNT_W{1'b0}}) begin
      refresh_q <= 1'b1;
    end else if (state_q == STATE_REFRESH) begin
      refresh_q <= 1'b0;
    end
  end


  //-----------------------------------------------------------------
  // Bank Logic
  //-----------------------------------------------------------------
  integer idx;

  always @(posedge clock) begin
    if (reset) begin
      for (idx = 0; idx < DDR_BANKS; idx = idx + 1) begin
        active_row_q[idx] <= {DDR_ROW_W{1'b0}};
      end

      row_open_q <= {DDR_BANKS{1'b0}};
    end else begin
      case (state_q)
        //-----------------------------------------
        // STATE_IDLE / Default (delays)
        //-----------------------------------------
        default: begin
          if (!cfg_enable_i) row_open_q <= {DDR_BANKS{1'b0}};
        end
        //-----------------------------------------
        // STATE_ACTIVATE
        //-----------------------------------------
        STATE_ACTIVATE: begin
          active_row_q[addr_bank_w] <= addr_row_w;
          row_open_q[addr_bank_w]   <= 1'b1;
        end
        //-----------------------------------------
        // STATE_PRECHARGE
        //-----------------------------------------
        STATE_PRECHARGE: begin
          // Precharge due to refresh, close all banks
          if (target_state_q == STATE_REFRESH) begin
            // Precharge all banks
            row_open_q <= {DDR_BANKS{1'b0}};
          end else begin
            // Precharge specific banks
            row_open_q[addr_bank_w] <= 1'b0;
          end
        end
      endcase
    end
  end


  //-----------------------------------------------------------------
  // Command
  //-----------------------------------------------------------------
  reg [     CMD_W-1:0] command_r;
  reg [ASB:0] addr_r;
  reg                  cke_r;
  reg [BSB:0] bank_r;

  always @* begin
    command_r = CMD_NOP;
    addr_r    = {DDR_ROW_W{1'b0}};
    bank_r    = {DDR_BBITS{1'b0}};
    cke_r     = 1'b1;

    case (state_q)
      //-----------------------------------------
      // STATE_INIT
      //-----------------------------------------
      STATE_INIT: begin
        // Assert CKE after 500uS
        if (refresh_timer_q > 2500) cke_r = 1'b0;

        if (refresh_timer_q == 2400) begin
          command_r = CMD_LOAD_MODE;
          bank_r    = 3'd2;
          addr_r    = MR2_REG;
        end

        if (refresh_timer_q == 2300) begin
          command_r = CMD_LOAD_MODE;
          bank_r    = 3'd3;
          addr_r    = MR3_REG;
        end

        if (refresh_timer_q == 2200) begin
          command_r = CMD_LOAD_MODE;
          bank_r    = 3'd1;
          addr_r    = MR1_REG;
        end

        if (refresh_timer_q == 2100) begin
          command_r = CMD_LOAD_MODE;
          bank_r    = 3'd0;
          addr_r    = MR0_REG;
        end

        // Long ZQ calibration
        if (refresh_timer_q == 2000) begin
          command_r  = CMD_ZQCL;
          addr_r[10] = 1;
        end

        // --- 

        // PRECHARGE
        if (refresh_timer_q == 10) begin
          // Precharge all banks
          command_r         = CMD_PRECHARGE;
          addr_r[ALL_BANKS] = 1'b1;
        end
      end
      //-----------------------------------------
      // STATE_IDLE
      //-----------------------------------------
      STATE_IDLE: begin
        if (!cfg_enable_i && cfg_stb_i)
          {cke_r, addr_r, bank_r, command_r} = cfg_data_i[CMD_W+DDR_ROW_W+DDR_BANKS:0];
      end
      //-----------------------------------------
      // STATE_ACTIVATE
      //-----------------------------------------
      STATE_ACTIVATE: begin
        // Select a row and activate it
        command_r = CMD_ACTIVE;
        addr_r    = addr_row_w;
        bank_r    = addr_bank_w;
      end
      //-----------------------------------------
      // STATE_PRECHARGE
      //-----------------------------------------
      STATE_PRECHARGE: begin
        // Precharge due to refresh, close all banks
        if (target_state_r == STATE_REFRESH) begin
          // Precharge all banks
          command_r         = CMD_PRECHARGE;
          addr_r[ALL_BANKS] = 1'b1;
        end else begin
          // Precharge specific banks
          command_r         = CMD_PRECHARGE;
          addr_r[ALL_BANKS] = 1'b0;
          bank_r            = addr_bank_w;
        end
      end
      //-----------------------------------------
      // STATE_REFRESH
      //-----------------------------------------
      STATE_REFRESH: begin
        // Auto refresh
        command_r = CMD_REFRESH;
        addr_r    = {DDR_ROW_W{1'b0}};
        bank_r    = {DDR_BANKS{1'b0}};
      end
      //-----------------------------------------
      // STATE_READ
      //-----------------------------------------
      STATE_READ: begin
        command_r              = CMD_READ;
        addr_r                 = {addr_col_w[ASB:3], 3'b0};
        bank_r                 = addr_bank_w;

        // Disable auto precharge (auto close of row)
        addr_r[AUTO_PRECHARGE] = 1'b0;
      end
      //-----------------------------------------
      // STATE_WRITE
      //-----------------------------------------
      STATE_WRITE: begin
        command_r              = CMD_WRITE;
        addr_r                 = {addr_col_w[ASB:3], 3'b0};
        bank_r                 = addr_bank_w;

        // Disable auto precharge (auto close of row)
        addr_r[AUTO_PRECHARGE] = 1'b0;
      end
      default: ;
    endcase
  end


  //-----------------------------------------------------------------
  // ACK
  //-----------------------------------------------------------------
  reg write_ack_q;

  always @(posedge clock) begin
    if (reset) begin
      write_ack_q <= 1'b0;
    end else begin
      write_ack_q <= (state_q == STATE_WRITE) && cmd_accept_w;
    end
  end

`ifdef __use_slow_fifo
  initial begin : YUCKY
    $display("Using SLOW FIFO");
  end  // YUCKY

  slow_fifo #(
        .WIDTH(TRAN_ID_WIDTH)
      , .ABITS(3)
  ) u_id_fifo (
        .clock(clock)
      , .reset(reset)

      , .wren_i  (ram_req_w & ram_accept_w)
      , .data_i  (mem_req_id_i)
      , .accept_o(id_fifo_space_w)

      , .valid_o()
      , .data_o (mem_resp_id_o)
      , .rden_i (ram_ack_w)
  );
`else
  sync_fifo #(
        .WIDTH (TRAN_ID_WIDTH)
      , .ABITS (3)
      , .OUTREG(0)
  ) u_id_fifo (
        .clock(clock)
      , .reset(reset)

      , .valid_i(ram_req_w & ram_accept_w)
      , .ready_o(id_fifo_space_w)
      , .data_i (mem_req_id_i)

      , .valid_o()
      , .ready_i(ram_ack_w)
      , .data_o (mem_resp_id_o)
  );
`endif

  assign ram_ack_w = sdram_rd_valid_w || write_ack_q;

  // Accept command in READ or WRITE0 states
  assign ram_accept_w = (state_q == STATE_READ || state_q == STATE_WRITE) && cmd_accept_w;

  // Config stall
  assign cfg_stall_o = ~(state_q == STATE_IDLE && cmd_accept_w);


  //-----------------------------------------------------------------
  // DDR3 DFI Interface
  //-----------------------------------------------------------------
  ddr3_dfi_seq #(
      .DDR_MHZ(DDR_MHZ)
      , .DDR_WRITE_LATENCY(DDR_WRITE_LATENCY)
      , .DDR_READ_LATENCY(DDR_READ_LATENCY)
  ) u_seq (
        .clock(clock)
      , .reset(reset)

      , .address_i(addr_r)
      , .bank_i(bank_r)
      , .command_i(command_r)
      , .cke_i(cke_r)
      , .accept_o(cmd_accept_w)

      , .wrdata_i(ram_write_data_w)
      , .wrdata_mask_i(~ram_wr_w)

      , .rddata_valid_o(sdram_rd_valid_w)
      , .rddata_o(sdram_data_in_w)

      , .dfi_address_o(dfi_address_o)
      , .dfi_bank_o(dfi_bank_o)
      , .dfi_cas_n_o(dfi_cas_n_o)
      , .dfi_cke_o(dfi_cke_o)
      , .dfi_cs_n_o(dfi_cs_n_o)
      , .dfi_odt_o(dfi_odt_o)
      , .dfi_ras_n_o(dfi_ras_n_o)
      , .dfi_reset_n_o(dfi_reset_n_o)
      , .dfi_we_n_o(dfi_we_n_o)
      , .dfi_wrdata_o(dfi_wrdata_o)
      , .dfi_wrdata_en_o(dfi_wrdata_en_o)
      , .dfi_wrdata_mask_o(dfi_wrdata_mask_o)
      , .dfi_rddata_en_o(dfi_rddata_en_o)
      , .dfi_rddata_i(dfi_rddata_i)
      , .dfi_rddata_valid_i(dfi_rddata_valid_i)
      , .dfi_rddata_dnv_i(dfi_rddata_dnv_i)
  );

  // Read data output
  assign ram_read_data_w = sdram_data_in_w;


  //-----------------------------------------------------------------
  // Simulation only
  //-----------------------------------------------------------------
`ifdef __icarus
  reg [79:0] dbg_state;

  always @* begin
    case (state_q)
      STATE_INIT:      dbg_state = "INIT";
      STATE_DELAY:     dbg_state = "DELAY";
      STATE_IDLE:      dbg_state = "IDLE";
      STATE_ACTIVATE:  dbg_state = "ACTIVATE";
      STATE_READ:      dbg_state = "READ";
      STATE_WRITE:     dbg_state = "WRITE";
      STATE_PRECHARGE: dbg_state = "PRECHARGE";
      STATE_REFRESH:   dbg_state = "REFRESH";
      default:         dbg_state = "UNKNOWN";
    endcase
  end
`endif


endmodule  // ddr3_fsm
