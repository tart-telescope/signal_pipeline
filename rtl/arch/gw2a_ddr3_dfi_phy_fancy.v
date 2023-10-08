`timescale 1ns / 100ps
/**
 * DDR3 PHY for GoWin GW2A FPGA's, and using the DDR3 PHY Interface (DFI).
 */
module gw2a_ddr3_dfi_phy_fancy (  /*AUTOARG*/);

  // -- DQS (Local, Data-Capture Clocks) -- //

localparam DDR_FIFO_MODE = 1'b0;
localparam GDDR_FIFO_MODE = 1'b1;

  DQS
  #(.FIFO_MODE_SEL(DDR_FIFO_MODE),
    .RD_PNTR(),
    .DQS_MODE(),
    .HWL(),
    .GSREN()
  ) dqs_inst [QSB:0]
  ( .DQSR90(),
    .DQSW0(),
    .DQSW270(),
    .RPOINT(),
    .WPOINT(),
    .RBURST(),
    .RFLAG(),
    .WFLAG(),
    .DQSIN(),
    .DLLSTEP(),
    .WSTEP(),
    .READ(),
    .RLOADN(),
    .RMOVE(),
    .RDIR(),
    .WLOADN(),
    .WMOVE(),
    .WDIR(),
    .HOLD(),
    .RCLKSEL(),
    .PCLK(),
    .FCLK(),
    .RESET()
    );

endmodule // gw2a_ddr3_dfi_phy_fancy
