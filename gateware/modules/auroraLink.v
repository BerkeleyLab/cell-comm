module auroraLink #(
    parameter MGT_DEBUG         = "false",
    parameter CONVERSION_DEBUG  = "false",
    parameter USE_INTERNAL_MMCM = "false",
    parameter MGT_PROTOCOL      = "AURORA_64B66B"
) (
    /* Control and status */
    input  wire        sysClk,
    input  wire [31:0] GPIO_OUT,
    output wire [31:0] mgtCSR,
    input  wire        mgtCSRstrobe,
    output wire        auResetOut,
    /* MGT clock and IO */
    input  wire        refClk,
    output wire        MGT_TX_P,
    output wire        MGT_TX_N,
    input  wire        MGT_RX_P,
    input  wire        MGT_RX_N,
    /* Clocks in case of external MMCMM */
    input  wire        auMGTclkIn,
    input  wire        auUserClkIn,
    input  wire        mmcmLockedIn,
    /* Clocks in case of internal MMCMM */
    output wire        auMGTclkOut,
    output wire        auUserClkOut,
    output wire        mmcmLockedOut,
    /* Axi stream 32 bit interface */
    output wire [31:0] axiRxTdata,
    output wire [3:0]  axiRxTkeep,
    output wire [7:0]  axiRxTuser,
    output wire        axiRxTlast,
    output wire        axiRxTvalid,

    input  wire [31:0] axiTxTdata,
    output wire        axiTxTready,
    input  wire        axiTxTlast,
    input  wire        axiTxTvalid
);

if(MGT_PROTOCOL == "AURORA_64B66B") begin
    wire [63:0]   axiRxTdata64b;
    wire  [7:0]   axiRxTkeep64b;
    wire          axiRxTlast64b;
    wire          axiRxTvalid64b;

    wire [63:0]   axiTxTdata64b;
    wire  [7:0]   axiTxTkeep64b;
    wire          axiTxTvalid64b;
    wire          axiTxTlast64b;
    wire          axiTxTready64b;

    wire          axiCrcPass;
    wire          axiCrcValid;

    /* Async assertion and sync deassertion reset */
    reg [2:0] auResetSync = 0;
    wire      resetOut;
    always @(posedge auMGTclkOut or posedge resetOut) begin
        if (resetOut) auResetSync <= 3'b111;
        else auResetSync <= {auResetSync[1:0], 1'b0};
    end
    assign auResetOut = auResetSync[2];

    auroraMGT #(
        .DEBUG(MGT_DEBUG),
        .INTERNAL_MMCM(USE_INTERNAL_MMCM)
    ) auroraMGTInst (
        /* CSR */
        .sysClk(sysClk),                                        // input
        .GPIO_OUT(GPIO_OUT),                                    // input  [31:0]
        .mgtCSRstrobe(mgtCSRstrobe),                            // input
        .mgtCSR(mgtCSR),                                        // output [31:0]
        .mgtResetOut(resetOut),                                 // output

        .refClkIn(refClk),                                      // input
        .syncClkIn(auUserClkIn),                                // input
        .userClkIn(auMGTclkIn),                                 // input
        .mmcmNotLockedIn(mmcmLockedIn),                         // input
        .userClkOut(auMGTclkOut),                               // output
        .syncClkOut(auUserClkOut),                              // output
        .mmcmNotLockedOut(mmcmLockedOut),                       // output

        .tx_p(MGT_TX_P),                                        // output
        .tx_n(MGT_TX_N),                                        // output
        .rx_p(MGT_RX_P),                                        // input
        .rx_n(MGT_RX_N),                                        // input

        .axiRXtdata(axiRxTdata64b),                             // output [63:0]
        .axiRXtkeep(axiRxTkeep64b),                             // output [7:0]
        .axiRXtlast(axiRxTlast64b),                             // output
        .axiRXtValid(axiRxTvalid64b),                           // output

        .axiTXtdata(axiTxTdata64b),                             // input  [63:0]
        .axiTXtkeep(axiTxTkeep64b),                             // input  [7:0]
        .axiTXtvalid(axiTxTvalid64b),                           // input
        .axiTXtlast(axiTxTlast64b),                             // input
        .axiTXtready(axiTxTready64b),                           // output
        .axiCrcPass(axiCrcPass),                                // output
        .axiCrcValid(axiCrcValid));                             // output

    wire [7:0] axiTuser = {6'b0, axiCrcValid, axiCrcPass};

    axiDataUpconverter axiDataUpconverterInst (
        /* Input stage 32-bit */
        .sAxiStreamTdata(axiTxTdata),                           // input  [31:0]
        .sAxiStreamTlast(axiTxTlast),                           // input
        .sAxiStreamTready(axiTxTready),                         // output
        .sAxiStreamTvalid(axiTxTvalid),                         // input
        .sClk(auUserClkOut),                                    // input
        /* Output stage 64-bit */
        .mAxiStreamTdata(axiTxTdata64b),                        // output [63:0]
        .mAxiStreamTkeep(axiTxTkeep64b),                        // output [7:0]
        .mAxiStreamTlast(axiTxTlast64b),                        // output
        .mAxiStreamTready(axiTxTready64b),                      // input
        .mAxiStreamTvalid(axiTxTvalid64b),                      // output
        .mClk(auMGTclkOut),                                     // input
        .resetN(~auResetOut));                                    // input

    axiDataDownconverter axiDataDownconverterInst(
        /* Input stage 64-bit */
        .sAxiStreamTdata(axiRxTdata64b),                        // input  [63:0]
        .sAxiStreamTkeep(axiRxTkeep64b),                        // input  [7:0]
        .sAxiStreamTuser(axiTuser),                             // input  [7:0]
        .sAxiStreamTlast(axiRxTlast64b),                        // input
        .sAxiStreamTvalid(axiRxTvalid64b),                      // input
        .sClk(auMGTclkOut),                                     // input
        /* Output stage 32-bit */
        .mAxiStreamTdata(axiRxTdata),                           // output [31:0]
        .mAxiStreamTkeep(axiRxTkeep),                           // output [3:0]
        .mAxiStreamTuser(axiRxTuser),                           // output [7:0]
        .mAxiStreamTlast(axiRxTlast),                           // output
        .mAxiStreamTvalid(axiRxTvalid),                         // output
        .mClk(auUserClkOut),                                    // input
        .resetN(~auResetOut));                                    // input

    // Debugging
    `ifndef SIMULATE
        if (CONVERSION_DEBUG == "true") begin
            ila_td400_s4096_cap ila_aurora_link_inst (
                .clk(auMGTclkOut),
                .probe0({
                    axiRxTdata,
                    axiRxTkeep,
                    axiRxTuser,
                    axiRxTlast,
                    axiRxTvalid,
                    axiRxTdata64b,
                    axiRxTkeep64b,
                    axiRxTlast64b,
                    axiRxTvalid64b,
                    axiTxTdata,
                    axiTxTready,
                    axiTxTlast,
                    axiTxTvalid,
                    axiTxTdata64b,
                    axiTxTkeep64b,
                    axiTxTvalid64b,
                    axiTxTlast64b,
                    axiTxTready64b,
                    resetOut,
                    auResetOut,
                    axiTuser}) // [399:0]
                );
            end
            `endif // `ifndef SIMULATE


end else if(MGT_PROTOCOL == "AURORA_8B10B") begin
    ERROR_AURORA_8B10B_NOT_YET_SUPPORTED();
end else begin
    MGT_PROTOCOL_IS_BAD_ONLY_AURORA_8B10B_OR_64B66B_ALLOWED();
end // AURORA PROTOCOL

endmodule
