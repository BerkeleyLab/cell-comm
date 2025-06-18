/*
 * Aurora 64b66b MGT wrapper
 *
 * The module handles the sync clock and user clock according the value of the
 * INTERNAL_MMCM parameter:
 * - INTERNAL_MMCM = 'false':
 *     The clock syncClkIn and userClkIn are used and forwarded to userClkOut
 *     and syncClkOut.
 * - INTERNAL_MMCM = 'true':
 *     The clock is generated using the internal MMCM and propagated to the
 *     outside via userClkOut and syncClkOut.
 *
 */

module auroraMGT #(
    parameter  DEBUG                = "false",
    parameter  INTERNAL_MMCM        = "false",
    parameter  ALLOW_MMCM_RESET     = "false"
    ) (
    /* CSR */
    input               sysClk,
    input               mgtCSRstrobe,
    output     [31:0]   mgtCSR,
    input      [31:0]   GPIO_OUT,
    output              mgtResetOut,

    /* MGT Clocks */
    input               refClkIn,
    input               syncClkIn,
    input               userClkIn,
    output              userClkOut,
    output              syncClkOut,
    input               mmcmNotLockedIn,
    output              mmcmNotLockedOut,

    /* MGT pins */
    output              tx_p,
    output              tx_n,
    input               rx_p,
    input               rx_n,

    /* AXI interface */
    output     [63:0]   axiRXtdata,
    output      [7:0]   axiRXtkeep,
    output              axiRXtlast,
    output              axiRXtValid,
    input      [63:0]   axiTXtdata,
    input       [7:0]   axiTXtkeep,
    input               axiTXtvalid,
    input               axiTXtlast,
    output              axiTXtready,
    output              axiCrcPass,
    output              axiCrcValid,

    /* Status from aurora core */
    output              mgtHardErr,
    output              mgtSoftErr,
    output              mgtLaneUp,
    output              mgtChannelUP,
    output              mgtTxResetDone,
    output              mgtRxResetDone,
    output              mgtMmcmNotLocked);


//////////////////////////////////////////////////////////////////////////////
// Parameters
localparam GT_CONTROL_REG_WIDTH    = 6;
localparam GT_STATUS_REG_WIDTH     = 12;
// Control signal initial state
localparam POWER_DOWN_INIT_STATE   = 1'b0;
localparam RESET_INIT_STATE        = 1'b0;
localparam GT_RESET_INIT_STATE     = 1'b0;
localparam TX_POLARITY_INIT_STATE  = 1'b0;
localparam TX_PMA_RESET_INIT_STATE = 1'b0;
localparam TX_PCS_RESET_INIT_STATE = 1'b0;
// Clock
wire mmcmNotLocked, cpllLock, mmcmClkInLock;
wire txOutClk, userClkMMCM, syncClkMMCM;
// Controls
wire reset, gtReset, powerDown, txPolarity, txPMAreset, txPCSreset;
// Errors and status
wire gtPllLock, hardErr, softErr, laneUp, channelUP, sysCrcPass,
     gtCrcValid, gtCrcPass, txResetDone, rxResetDone;
(*ASYNC_REG="true"*) reg sysHardErr, sysHardErr_m,
                         sysSoftErr,  sysSoftErr_m,
                         sysLaneUp,  sysLaneUp_m,
                         sysChannelUP,  sysChannelUP_m,
                         sysCrcValid,  sysCrcValid_m,
                         sysGtCrcPass,  sysGtCrcPass_m,
                         sysTxResetDone,  sysTxResetDone_m,
                         sysRxResetDone,  sysRxResetDone_m,
                         sysMmcmNotLocked, sysMmcmNotLocked_m;
wire [1:0] txBufStatus;
wire [2:0] rxBufStatus;

//////////////////////////////////////////////////////////////////////////////
// Sync clock and User clock generation
if (INTERNAL_MMCM == "true") begin
    if (ALLOW_MMCM_RESET == "true") begin
        assign mmcmClkInLock = gtPllLock;
    end else if (ALLOW_MMCM_RESET == "false") begin
        assign mmcmClkInLock = cpllLock;
    end else begin
        ERROR_ALLOW_MMCM_RESET_IS_NEITHER_TRUE_OR_FALSE();
    end
    auroraMMCM #()
        auroraCWmmcm (
        .TX_CLK(txOutClk),              // input
        .CLK_LOCKED(mmcmClkInLock),     // input
        .USER_CLK(userClkMMCM),         // output
        .SYNC_CLK(syncClkMMCM),         // output
        .MMCM_NOT_LOCKED(mmcmNotLocked) // output
    );
    assign userClkOut = userClkMMCM;
    assign syncClkOut = syncClkMMCM;
end else if (INTERNAL_MMCM == "false") begin
    assign userClkOut = userClkIn;
    assign syncClkOut = syncClkIn;
    assign mmcmNotLocked = mmcmNotLockedIn;
end else begin
    ERROR_INTERNAL_MMCM_ONLY_TRUE_OR_FALSE_ALLOWED();
end
assign mmcmNotLockedOut = mmcmNotLocked;

//////////////////////////////////////////////////////////////////////////////
// Status and control signals
/* MGT control signals table
 __________________________________________________________________________
| GPIO INDEX  |  HEX VALUE   |          MGT INDEX        | MGT CONNECTIONS |
|-------------|--------------|---------------------------|-----------------|
| GPIO_OUT[5] | (0x00000020) | mgtControl[5], mgtCSR[17] | txPolarity      |
| GPIO_OUT[4] | (0x00000010) | mgtControl[4], mgtCSR[16] | txPMAreset      |
|-------------|--------------|---------------------------|-----------------|
| GPIO_OUT[3] | (0x00000008) | mgtControl[3], mgtCSR[15] | txPCSreset      |
| GPIO_OUT[2] | (0x00000004) | mgtControl[2], mgtCSR[14] | gtReset         |
| GPIO_OUT[1] | (0x00000002) | mgtControl[1], mgtCSR[13] | reset           |
| GPIO_OUT[0] | (0x00000001) | mgtControl[0], mgtCSR[12] | powerDown       |
'--------------------------------------------------------------------------' */

/* MGT status signals table
 _________________________________________________________________
| GPIO INDEX  |  HEX VALUE   |    MGT INDEX     | MGT CONNECTIONS |
|-------------|--------------|------------------|-----------------|
| GPIO_IN[11] | (0x00000800) |    mgtCSR[11]    | hardErr         |
| GPIO_IN[10] | (0x00000400) |    mgtCSR[10]    | softErr         |
| GPIO_IN[9]  | (0x00000200) |    mgtCSR[9]     | laneUp          |
| GPIO_IN[8]  | (0x00000100) |    mgtCSR[8]     | channelUP       |
|-------------|--------------|------------------|-----------------|
| GPIO_IN[7]  | (0x00000080) |    mgtCSR[7]     |    ---          |
| GPIO_IN[6]  | (0x00000040) |    mgtCSR[6]     | gtCrcValid      |
| GPIO_IN[5]  | (0x00000020) |    mgtCSR[5]     | gtCrcPass       |
| GPIO_IN[4]  | (0x00000010) |    mgtCSR[4]     | txResetDone     |
|-------------|--------------|------------------|-----------------|
| GPIO_IN[3]  | (0x00000008) |    mgtCSR[3]     | rxResetDone     |
| GPIO_IN[2]  | (0x00000004) |    mgtCSR[2]     | mmcmNotLocked   |
| GPIO_IN[1]  | (0x00000002) |    mgtCSR[1]     | gtPllLock       |
| GPIO_IN[0]  | (0x00000001) |    mgtCSR[0]     | cpllLock        |
'-----------------------------------------------------------------'
*/

assign sysCrcPass = sysCrcValid? sysGtCrcPass : 1'b0;
assign axiCrcPass = gtCrcPass;
assign axiCrcValid = gtCrcValid;

assign mgtHardErr         = hardErr;
assign mgtSoftErr         = softErr;
assign mgtLaneUp          = laneUp;
assign mgtChannelUP       = channelUP;
assign mgtTxResetDone     = txResetDone;
assign mgtRxResetDone     = rxResetDone;
assign mgtMmcmNotLocked   = mmcmNotLocked;
assign mgtResetOut        = reset;

reg [GT_CONTROL_REG_WIDTH-1:0] mgtControl = {POWER_DOWN_INIT_STATE,
                                             RESET_INIT_STATE,
                                             GT_RESET_INIT_STATE,
                                             TX_POLARITY_INIT_STATE,
                                             TX_PMA_RESET_INIT_STATE,
                                             TX_PCS_RESET_INIT_STATE};
assign {txPolarity,
        txPMAreset,
        txPCSreset,
        gtReset,
        reset,
        powerDown} = mgtControl;
wire [GT_STATUS_REG_WIDTH-1:0] mgtStatus;
assign mgtStatus = {sysHardErr,
                    sysSoftErr,
                    sysLaneUp,
                    sysChannelUP,
                    sysCrcPass,
                    sysCrcValid,
                    sysGtCrcPass,
                    sysTxResetDone,
                    sysRxResetDone,
                    sysMmcmNotLocked,
                    gtPllLock,
                    cpllLock};

assign mgtCSR = {{32-GT_CONTROL_REG_WIDTH-GT_STATUS_REG_WIDTH{1'b0}},
                  mgtControl, mgtStatus};

always @(posedge sysClk) begin
    if (mgtCSRstrobe) begin
        mgtControl <= GPIO_OUT[GT_CONTROL_REG_WIDTH-1:0];
    end
end

/* MGT Control CDC from userClk to sysClk */
always @(posedge sysClk) begin
    sysHardErr <= sysHardErr_m;
    sysHardErr_m <= hardErr;
    sysSoftErr <= sysSoftErr_m;
    sysSoftErr_m <= softErr;
    sysLaneUp <= sysLaneUp_m;
    sysLaneUp_m <= laneUp;
    sysChannelUP <= sysChannelUP_m;
    sysChannelUP_m <= channelUP;
    sysCrcValid <= sysCrcValid_m;
    sysCrcValid_m <= gtCrcValid;
    sysGtCrcPass <= sysGtCrcPass_m;
    sysGtCrcPass_m <= gtCrcPass;
    sysTxResetDone <= sysTxResetDone_m;
    sysTxResetDone_m <= txResetDone;
    sysRxResetDone <= sysRxResetDone_m;
    sysRxResetDone_m <= rxResetDone;
    sysMmcmNotLocked <= sysMmcmNotLocked_m;
    sysMmcmNotLocked_m <= mmcmNotLocked;
end

////////////////////////////////////////////////////////////////////////////////
// Debugging
`ifndef SIMULATE
if (DEBUG == "true") begin
    ila_td400_s4096_cap ila_auroraMGT_inst (
        .clk(sysClk),
        .probe0({
            axiTXtdata,
            axiRXtdata,
            gtPllLock,
            mmcmNotLocked,
            axiRXtValid,
            axiRXtkeep,
            axiRXtlast,
            powerDown,
            reset,
            gtReset,
            txPolarity,
            txPMAreset,
            txPCSreset,
            axiTXtvalid,
            axiTXtlast,
            axiTXtready,
            axiTXtkeep,
            hardErr,
            softErr,
            laneUp,
            channelUP,
            gtCrcValid,
            gtCrcPass,
            txResetDone,
            rxResetDone,
            cpllLock,
            rxBufStatus,
            txBufStatus,
            mgtCSRstrobe
        }) // [399:0]
    );
end
`endif // `ifndef SIMULATE

////////////////////////////////////////////////////////////////////////////////
// Aurora IP instance
`ifndef SIMULATE
aurora64b66b aurora64b66bInst (
    // TX AXI4-S Interface
    .s_axi_tx_tdata(axiTXtdata),        // input  [0:63]
    .s_axi_tx_tkeep(axiTXtkeep),        // input  [0:7]
    .s_axi_tx_tlast(axiTXtlast),        // input
    .s_axi_tx_tvalid(axiTXtvalid),      // input
    .s_axi_tx_tready(axiTXtready),      // output
    // RX AXI4-S Interface
    .m_axi_rx_tdata(axiRXtdata),        // output [0:63]
    .m_axi_rx_tkeep(axiRXtkeep),        // output [0:7]
    .m_axi_rx_tlast(axiRXtlast),        // output
    .m_axi_rx_tvalid(axiRXtValid),      // output
    // GTX Serial I/O
    .rxp(rx_p),                         // input
    .rxn(rx_n),                         // input
    .txp(tx_p),                         // output
    .txn(tx_n),                         // output
    //GTX Reference Clock Interface
    .refclk1_in(refClkIn),              // input
    .hard_err(hardErr),                 // output
    .soft_err(softErr),                 // output
    // Status
    .channel_up(channelUP),             // output
    .lane_up(laneUp),                   // output
    .crc_pass_fail_n(gtCrcPass),        // output
    .crc_valid(gtCrcValid),             // output
    // System Interface
    .mmcm_not_locked(mmcmNotLocked),    // input
    .user_clk(userClkOut),              // input
    .sync_clk(syncClkOut),              // input
    .reset_pb(reset),                   // input
    .gt_rxcdrovrden_in(1'b0),           // input
    .power_down(powerDown),             // input
    .loopback(3'b0),                    // input [2:0]
    .pma_init(gtReset),                 // input
    .gt_pll_lock(gtPllLock),            // output
    .drp_clk_in(sysClk),                // input
    // GT quad assignment
    .gt_qpllclk_quad1_in(1'b0),         // input
    .gt_qpllrefclk_quad1_in(1'b0),      // input
    // GT DRP Ports
    .drpaddr_in(9'b0),                  // input  [8:0]
    .drpdi_in(16'b0),                   // input  [15:0]
    .drpen_in(1'b0),                    // input
    .drpwe_in(1'b0),                    // input
    .drpdo_out(),                       // output [15:0]
    .drprdy_out(),                      // output
    .init_clk(sysClk),                  // input
    .link_reset_out(),                  // output
    .gt_rxusrclk_out(),                 // output
    //------------------------ RX Margin Analysis Ports ------------------------
    .gt0_eyescandataerror_out(),        // output
    .gt0_eyescanreset_in(1'b0),         // input
    .gt0_eyescantrigger_in(1'b0),       // input
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    .gt0_rxcdrhold_in(1'b0),            // input
    .gt0_rxlpmhfovrden_in(1'b0),        // input
    .gt0_rxdfeagchold_in(1'b0),         // input
    .gt0_rxdfeagcovrden_in(1'b0),       // input
    .gt0_rxdfelfhold_in(1'b0),          // input
    .gt0_rxdfelpmreset_in(1'b0),        // input
    .gt0_rxlpmlfklovrden_in(1'b0),      // input
    .gt0_rxmonitorout_out(),            // output [6:0]
    .gt0_rxmonitorsel_in(2'b0),         // input  [1:0]
    .gt0_rxlpmen_in(1'b1),              // input
    .gt0_rxpmareset_in(1'b0),           // input
    .gt0_rxpcsreset_in(1'b0),           // input
    .gt0_rxbufreset_in(1'b0),           // input
    .gt0_rxprbssel_in(3'b0),            // input  [2:0]
    .gt0_rxprbserr_out(),               // output
    .gt0_rxprbscntreset_in(1'b0),       // input
    .gt0_rxresetdone_out(rxResetDone),  // output
    .gt0_rxbufstatus_out(rxBufStatus),  // output [2:0]
    //---------------------- TX Configurable Driver Ports ----------------------
    .gt0_txpostcursor_in(5'b0),         // input  [4:0]
    .gt0_txdiffctrl_in(4'b1000),        // input  [3:0]
    .gt0_txmaincursor_in(7'b0),         // input  [6:0]
    .gt0_txprecursor_in(5'b0),          // input  [4:0]
    //--------------- Transmit Ports - TX Polarity Control Ports ---------------
    .gt0_txpolarity_in(1'b0),           // input
    .gt0_txinhibit_in(1'b0),            // input
    .gt0_txpmareset_in(txPMAreset),     // input
    .gt0_txpcsreset_in(txPCSreset),     // input
    .gt0_txprbssel_in(3'b0),            // input  [2:0]
    .gt0_txprbsforceerr_in(1'b0),       // input
    .gt0_txbufstatus_out(txBufStatus),  // output [1:0]
    .gt0_txresetdone_out(txResetDone),  // output
    .gt0_dmonitorout_out(),             // output [7:0]
    .gt0_cplllock_out(cpllLock),        // output
    .gt_qplllock(),                     // output
    .sys_reset_out(),                   // output
    .tx_out_clk(txOutClk)               // output
);
`endif // `ifndef SIMULATE
endmodule
