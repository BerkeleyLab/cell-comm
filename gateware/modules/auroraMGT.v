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
    parameter  MMCM_MULT            = 14,
    parameter  MMCM_DIVIDE          = 1,
    parameter  MMCM_CLK_PERIOD      = 10.240,
    parameter  MMCM_OUT0_DIVIDE     = 28,
    parameter  MMCM_OUT1_DIVIDE     = 14,
    parameter  MMCM_OUT2_DIVIDE     = 20,
    parameter  MMCM_OUT3_DIVIDE     = 8,
    parameter  FPGA_FAMILY          = "7series",
    parameter  DEBUG                = "false",
    parameter  MGT_PROTOCOL         = "AURORA_64B66B",
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
    input               initClkIn,
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
    output              mgtChannelUp,
    output              mgtTxResetDone,
    output              mgtRxResetDone,
    output              mgtMmcmNotLocked,

    output              txOutClk,
    output              txOutClkClr
);

generate
    if (FPGA_FAMILY != "7series" && FPGA_FAMILY != "ultrascaleplus") begin
        FPGA_FAMILY_unsupported error();
    end
endgenerate

generate
    if(MGT_PROTOCOL != "AURORA_64B66B" && MGT_PROTOCOL != "AURORA_8B10B") begin
        MGT_PROTOCOL_unsupported_AURORA_8B10B_OR_64B66B_ALLOWED error();
    end
endgenerate

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
wire txOutClkClrUnbuf, txOutClkUnbuf, userClkMMCM, syncClkMMCM;
wire refClk = refClkIn;
wire initClk;
// Controls
wire reset, gtReset, powerDown, txPolarity, txPMAreset, txPCSreset;
wire sysReset, sysGtReset, sysPowerDown, sysTxPolarity, sysTxPMAreset, sysTxPCSreset;
// Errors and status
wire gtPllLock, hardErr, softErr, laneUp, channelUp, sysCrcPass,
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
    auroraMMCM #(
        .FPGA_FAMILY  (FPGA_FAMILY),
        .MULT         (MMCM_MULT),
        .DIVIDE       (MMCM_DIVIDE),
        .CLK_PERIOD   (MMCM_CLK_PERIOD),
        .OUT0_DIVIDE  (MMCM_OUT0_DIVIDE),
        .OUT1_DIVIDE  (MMCM_OUT1_DIVIDE),
        .OUT2_DIVIDE  (MMCM_OUT2_DIVIDE),
        .OUT3_DIVIDE  (MMCM_OUT3_DIVIDE)
    )
        auroraCWmmcm (
        .TX_CLK(txOutClkUnbuf),         // input
        .TX_CLK_CLR(txOutClkClrUnbuf),  // input
        .CLK_LOCKED(mmcmClkInLock),     // input
        .USER_CLK(userClkMMCM),         // output
        .TX_CLK_OUT(txOutClk),          // output
        .SYNC_CLK(syncClkMMCM),         // output
        .MMCM_NOT_LOCKED(mmcmNotLocked) // output
    );
    assign userClkOut = userClkMMCM;
    assign syncClkOut = syncClkMMCM;
    assign txOutClkClr = txOutClkClrUnbuf;
end else if (INTERNAL_MMCM == "false") begin
    assign userClkOut = userClkIn;
    assign syncClkOut = syncClkIn;
    assign mmcmNotLocked = mmcmNotLockedIn;
    assign txOutClk = 1'b0;
    assign txOutClkClr = 1'b0;
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
| GPIO_IN[8]  | (0x00000100) |    mgtCSR[8]     | channelUp       |
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
assign mgtChannelUp       = channelUp;
assign mgtTxResetDone     = txResetDone;
assign mgtRxResetDone     = rxResetDone;
assign mgtMmcmNotLocked   = mmcmNotLocked;
assign mgtResetOut        = reset;

reg [GT_CONTROL_REG_WIDTH-1:0] mgtControl = {TX_POLARITY_INIT_STATE,
                                             TX_PMA_RESET_INIT_STATE,
                                             TX_PCS_RESET_INIT_STATE,
                                             GT_RESET_INIT_STATE,
                                             RESET_INIT_STATE,
                                             POWER_DOWN_INIT_STATE};
assign {sysTxPolarity,
        sysTxPMAreset,
        sysTxPCSreset,
        sysGtReset,
        sysReset,
        sysPowerDown} = mgtControl;

forwardMultiCDC #(
    .DATA_WIDTH(GT_CONTROL_REG_WIDTH)
)
  forwardSysToInitClk (
    .dataIn({
        sysTxPolarity,
        sysTxPMAreset,
        sysTxPCSreset,
        sysGtReset,
        sysReset,
        sysPowerDown
    }),
    .clk(initClk),
    .dataOut({
        txPolarity,
        txPMAreset,
        txPCSreset,
        gtReset,
        reset,
        powerDown
    })
);

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
    sysChannelUP_m <= channelUp;
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
            channelUp,
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

generate
if (FPGA_FAMILY == "7series") begin

    assign initClk = sysClk;
    assign txOutClkClrUnbuf = 1'b0;

    if (MGT_PROTOCOL == "AURORA_64B66B") begin
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
            .refclk1_in(refClk),                // input
            .hard_err(hardErr),                 // output
            .soft_err(softErr),                 // output
            // Status
            .channel_up(channelUp),             // output
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
            .drp_clk_in(initClk),               // input
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
            .init_clk(initClk),                 // input
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
            .tx_out_clk(txOutClkUnbuf)          // output
        );
    end

    if (MGT_PROTOCOL == "AURORA_8B10B") begin
        /* AXI 32-bit interface */
        wire [31:0]   axiTXtdata32;
        wire  [3:0]   axiTXtkeep32;
        wire          axiTXtvalid32;
        wire          axiTXtlast32;
        wire          axiTXtready32;

        axiDataDownconverter
          axiDataDownconverterInst(
            /* Input stage 64-bit */
            .sAxiStreamTdata(axiTXtdata),     // input  [63:0]
            .sAxiStreamTkeep(axiTXtkeep),     // input  [7:0]
            .sAxiStreamTuser(0),              // input  [7:0]
            .sAxiStreamTlast(axiTXtlast),     // input
            .sAxiStreamTvalid(axiTXtvalid),   // input
            .sClk(auMGTclkOut),               // input
            /* Output stage 32-bit */
            .mAxiStreamTdata(axiTXtdata32),   // output [31:0]
            .mAxiStreamTkeep(axiTXtkeep32),   // output [3:0]
            .mAxiStreamTuser(),               // output [7:0]
            .mAxiStreamTlast(axiTXtlast32),   // output
            .mAxiStreamTvalid(axiTXtvalid32), // output
            .mClk(auUserClkOut),              // input
            .resetN(~reset));                 // input

        wire [31:0]   axiRXtdata32;
        wire  [3:0]   axiRXtkeep32;
        wire          axiRXtvalid32;
        wire          axiRXtlast32;

        axiDataUpconverter
          axiDataUpconverterInst (
            /* Input stage 32-bit */
            .sAxiStreamTdata(axiRXtdata32),      // input  [31:0]
            .sAxiStreamTlast(axiRXtlast32),      // input
            .sAxiStreamTready(axiRXtready32),    // output
            .sAxiStreamTvalid(axiRXtvalid32),    // input
            .sClk(auUserClkOut),                 // input
            /* Output stage 64-bit */
            .mAxiStreamTdata(axiRXtdata),        // output [63:0]
            .mAxiStreamTkeep(axiRXtkeep),        // output [7:0]
            .mAxiStreamTlast(axiRXtlast),        // output
            .mAxiStreamTready(1'b1),             // input
            .mAxiStreamTvalid(axiRXtvalid),      // output
            .mClk(auMGTclkOut),                  // input
            .resetN(~reset));                    // input

        aurora_8b10b aurora_8b10b_inst (
            // AXI axiTx Interface
            .s_axi_tx_tdata(axiTXtdata32),       // input   [0:31]
            .s_axi_tx_tkeep(axiTXtkeep32),       // input   [0:3]
            .s_axi_tx_tvalid(axiTXtvalid32),     // input
            .s_axi_tx_tlast(axiTXtlast32),       // input
            .s_axi_tx_tready(axiTXtready32),     // output
            // AXI RX Interface
            .m_axi_rx_tdata(axiRXtdata32),       // output  [0:31]
            .m_axi_rx_tkeep(axiRXtkeep32),       // output  [0:3]
            .m_axi_rx_tvalid(axiRXtValid32),     // output
            .m_axi_rx_tlast(axiRXtlast32),       // output
            // GT Serial I/O
            .rxp(rx_p),                        // input
            .rxn(rx_n),                        // input
            .txp(tx_p),                        // output
            .txn(tx_n),                        // output
            // GT Reference Clock Interface
            .gt_refclk1(refClk),               // input
            // Error Detection Interface
            .frame_err(),                      // output
            .hard_err(hardErr),                // output
            .soft_err(softErr),                // output
            // Status
            .lane_up(laneUp),                  // output
            .channel_up(channelUp),            // output
            // CRC output status signals
            .crc_pass_fail_n(gtCrcPass),       // output
            .crc_valid(gtCrcValid),            // output
            // System Interface
            .user_clk(userClkOut),             // input
            .sync_clk(syncClkOut),             // input
            .gt_reset(gtReset),                // input
            .reset(reset),                     // input
            .sys_reset_out(),                  // output

            .power_down(powerDown),            // input
            .loopback(3'b0),                   // input   [2:0]
            .tx_lock(),                        // output

            .init_clk_in(initClk),             // input
            .tx_resetdone_out(txResetDone),    // output
            .rx_resetdone_out(rxResetDone),    // output
            .link_reset_out(),                 // output
            // DRP Ports
            .drpclk_in(initClk),               // input
            .drpaddr_in(9'b0),                 // input   [8:0]
            .drpen_in(1'b0),                   // input
            .drpdi_in(16'b0),                  // input   [15:0]
            .drprdy_out(),                     // output
            .drpdo_out(),                      // output  [15:0]
            .drpwe_in(1'b0),                   // input
            .gt0_cplllock_out(cpllLock),       // output
            // ---------- TX Configurable Driver Ports ---------------------------------
            .gt0_txpostcursor_in(5'b0),        // input   [4:0]
            .gt0_txprecursor_in(5'b0),         // input   [4:0]
            // ---------- Transmit Ports - TX 8B/10B Encoder Ports ---------------------
            .gt0_txchardispmode_in(4'b0),      // input   [3:0]
            .gt0_txchardispval_in(4'b0),       // input   [3:0]
            .gt0_txmaincursor_in(7'b0),        // input   [6:0]
            .gt0_tx_buf_err_out(),             // output
            .gt0_txdiffctrl_in(4'b0),          // input   [3:0]
            // ---------- Transmit Ports - TX Polarity Control Ports -------------------
            .gt0_txpolarity_in(1'b0),          // input
            // ---------- Transmit Ports - Pattern Generator Ports ---------------------
            .gt0_txprbsforceerr_in(1'b0),      // input
            .gt0_txprbssel_in(3'b0),           // input   [2:0]
            // ---------- Transmit Ports - TX Data Path interface ----------------------
            .gt0_txpcsreset_in(txPCSreset),    // input
            .gt0_txinhibit_in(1'b0),           // input
            .gt0_txpmareset_in(txPMAreset),    // input
            .gt0_txresetdone_out(),            // output
            .gt0_txbufstatus_out(txBufStatus), // output  [1:0]

            .gt0_rxresetdone_out(),            // output
            .gt0_rxbufstatus_out(rxBufStatus), // output  [2:0]
            // ---------- RX Margin Analysis Ports -------------------------------------
            .gt0_eyescanreset_in(),            // input
            .gt0_eyescandataerror_out(),       // output
            .gt0_eyescantrigger_in(),          // input
            .gt0_rxdfelpmreset_in(),           // input
            .gt0_rxlpmen_in(),                 // input
            .gt0_rxcdrovrden_in(),             // input
            .gt0_rxmonitorout_out(),           // output  [6:0]
            .gt0_rxmonitorsel_in(),            // input   [1:0]
            .gt0_rxcdrhold_in(),               // input
            .gt0_rxbyteisaligned_out(),        // output
            .gt0_rx_realign_out(),             // output
            .gt0_rx_buf_err_out(),             // output
            .gt0_rxcommadet_out(),             // output
            // ---------- Receive Ports - Pattern Checker Ports ------------------------
            .gt0_rxprbserr_out(),              // output
            .gt0_rxprbssel_in(),               // input   [2:0]
            // ---------- Receive Ports - Pattern Checker ports ------------------------
            .gt0_rxprbscntreset_in(),          // input
            // ---------- Receive Ports - RX Data Path interface -----------------------
            .gt0_rxpcsreset_in(),              // input
            .gt0_rxpmareset_in(),              // input
            .gt0_dmonitorout_out(),            // output  [7:0]
            // ---------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports --
            .gt0_rxbufreset_in(),              // input
            .gt0_rx_disp_err_out(),            // output  [3:0]
            .gt0_rx_not_in_table_out(),        // output  [3:0]
            // ____________________________ COMMON PORTS _______________________________
            .gt0_qplllock_in(),                // input
            .gt0_qpllrefclklost_in(),          // input
            .gt0_qpllreset_out(),              // output
            .gt_qpllclk_quad1_in(),            // input
            .gt_qpllrefclk_quad1_in(),         // input
            .tx_out_clk(txOutClkUnbuf),        // output
            .pll_not_locked()                  // input
         );
    end
end

if (FPGA_FAMILY == "ultrascaleplus") begin
    assign initClk = initClkIn;

    if (MGT_PROTOCOL == "AURORA_64B66B") begin
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
            .refclk1_in(refClk),                // input
            .hard_err(hardErr),                 // output
            .soft_err(softErr),                 // output
            // Status
            .channel_up(channelUp),             // output
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
            // GT DRP Ports
            .gt0_drpaddr(10'b0),                // input  [9:0]
            .gt0_drpdi(16'b0),                  // input  [15:0]
            .gt0_drpen(1'b0),                   // input
            .gt0_drpwe(1'b0),                   // input
            .gt0_drpdo(),                       // output [15:0]
            .gt0_drprdy(),                      // output
            .init_clk(initClk),                 // input
            .link_reset_out(),                  // output
            .gt_rxusrclk_out(),                 // output
            //------------------------ RX Margin Analysis Ports ------------------------
            .gt_eyescandataerror(),             // output
            .gt_eyescanreset(1'b0),             // input
            .gt_eyescantrigger(1'b0),           // input
            //------------------- Receive Ports - RX Equalizer Ports -------------------
            .gt_rxcdrhold(1'b0),                // input  [0:0]
            .gt_rxdfelpmreset(1'b0),            // input  [0:0]
            .gt_rxlpmen(1'b0),                  // input  [0:0]
            .gt_rxpmareset(1'b0),               // input  [0:0]
            .gt_rxpcsreset(1'b0),               // input  [0:0]
            .gt_rxrate(2'b0),                   // input  [2:0]
            .gt_rxbufreset(1'b0),               // input  [0:0]
            .gt_rxpmaresetdone(),               // output [0:0]
            .gt_rxprbssel(4'b0),                // input  [3:0]
            .gt_rxprbscntreset(1'b0),           // input  [0:0]
            .gt_rxprbserr(),                    // output [0:0]
            .gt_rxresetdone(rxResetDone),       // output [0:0]
            .gt_rxbufstatus(rxBufStatus),       // output [2:0]
            //---------------------- TX Configurable Driver Ports ----------------------
            .gt_txpostcursor(5'b0),             // input  [4:0]
            .gt_txdiffctrl(5'b11000),           // input  [4:0]
            .gt_txprecursor(5'b0),              // input  [4:0]
            //--------------- Transmit Ports - TX Polarity Control Ports ---------------
            .gt_txpolarity(1'b0),               // input
            .gt_txinhibit(1'b0),                // input
            .gt_txpmareset(txPMAreset),         // input
            .gt_txpcsreset(txPCSreset),         // input
            .gt_txprbssel(4'b0),                // input  [3:0]
            .gt_txprbsforceerr(1'b0),           // input
            .gt_txbufstatus(txBufStatus),       // output [1:0]
            .gt_txresetdone(txResetDone),       // output
            .gt_pcsrsvdin(16'b0),               // input  [15:0]
            .gt_dmonitorout(),                  // output [15:0]
            .gt_cplllock(cpllLock),             // output
            .gt_qplllock(),                     // output
            .gt_powergood(),                    // output [0:0]
            .gt_pll_lock(gtPllLock),            // output
            .bufg_gt_clr_out(txOutClkClrUnbuf), // output
            .sys_reset_out(),                   // output
            .tx_out_clk(txOutClkUnbuf)          // output
        );
    end

    if (MGT_PROTOCOL == "AURORA_8B10B") begin
        MGT_PROTOCOL_AURORA_8b10b_not_supported_for_ultrascaleplus error();
    end
end
endgenerate

`endif // `ifndef SIMULATE
endmodule
