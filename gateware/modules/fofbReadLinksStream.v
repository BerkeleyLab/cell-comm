module fofbReadLinksStream #(
    parameter SYSCLK_RATE      = 100000000,
    parameter FOFB_INDEX_WIDTH = -1,
    parameter MAX_CELLS        = 32,
    parameter CELL_INDEX_WIDTH = $clog2(MAX_CELLS),
    parameter    FAstrobeDebug = "false",
    parameter      statusDebug = "false",
    parameter     rawDataDebug = "false",
    parameter     ccwLinkDebug = "false",
    parameter      cwLinkDebug = "false",
    parameter   cellCountDebug = "false",
    parameter  dspReadoutDebug = "false"
) (
    input  wire        sysClk,

    // Control/Status
    input  wire                        csrStrobe,
    input  wire                 [31:0] GPIO_OUT,
    output wire                 [31:0] csr,
    output wire        [MAX_CELLS-1:0] fofbBitmapAllFASnapshot,
    output wire        [MAX_CELLS-1:0] fofbEnableBitmapFASnapshot,

    output wire        [MAX_CELLS-1:0] fofbBitmapAll,
    output wire        [MAX_CELLS-1:0] fofbBitmapEnabled,
    output wire                        fofbEnabled,

    // Synchronization
    input  wire                        FAstrobe,

    // Link statistics
    output wire                        sysStatusStrobe,
    output wire                  [2:0] sysStatusCode,
    output wire                        sysTimeoutStrobe,

    // Fast orbit feedback correction DSP
    output wire [FOFB_INDEX_WIDTH-1:0] fofbDSPreadoutIndex,
    output wire                 [31:0] fofbDSPreadoutX,
    output wire                 [31:0] fofbDSPreadoutY,
    output wire                 [31:0] fofbDSPreadoutS,
    output wire                        fofbDSPreadoutValid,

    // Values to microBlaze
    input  wire                        uBreadoutStrobe,
    output wire                 [31:0] uBreadoutX,
    output wire                 [31:0] uBreadoutY,
    output wire                 [31:0] uBreadoutS,

    // Start of Aurora user clock domain nets
    input  wire        auClk,
    input  wire        auFAstrobe,
    input  wire        auReset,
    output wire        auCCWcellInhibit,
    output wire        auCWcellInhibit,

    // Tap of outging cell links
    input  wire        auCellCCWlinkTVALID,
    input  wire        auCellCCWlinkTLAST,
    input  wire [31:0] auCellCCWlinkTDATA,

    input  wire        auCellCWlinkTVALID,
    input  wire        auCellCWlinkTLAST,
    input  wire [31:0] auCellCWlinkTDATA
);

// fofbReadLinks to readoutStream
wire [FOFB_INDEX_WIDTH-1:0] readoutAddress;
wire                 [31:0] readoutX, readoutY, readoutS;
wire                        readoutPresent;
wire                 [95:0] fofbReadout = {readoutX,
                                           readoutY,
                                           readoutS};

// readoutStream to output
wire [95:0] fofbData;
assign {fofbDSPreadoutX,
        fofbDSPreadoutY,
        fofbDSPreadoutS} = fofbData;


fofbReadLinks #(
    .SYSCLK_RATE(SYSCLK_RATE),
    .FOFB_INDEX_WIDTH(FOFB_INDEX_WIDTH),
    .FAstrobeDebug(FAstrobeDebug),
    .statusDebug(statusDebug),
    .rawDataDebug(rawDataDebug),
    .ccwLinkDebug(ccwLinkDebug),
    .cwLinkDebug(cwLinkDebug),
    .cellCountDebug(cellCountDebug),
    .dspReadoutDebug(dspReadoutDebug))
fofbReadLinksInst (
    .sysClk(sysClk),
    .csrStrobe(csrStrobe),
    .GPIO_OUT(GPIO_OUT),
    .csr(csr),
    .fofbBitmapAllFASnapshot(fofbBitmapAllFASnapshot),
    .fofbEnableBitmapFASnapshot(fofbEnableBitmapFASnapshot),
    .fofbBitmapAll(fofbBitmapAll),
    .fofbBitmapEnabled(fofbBitmapEnabled),
    .fofbEnabled(fofbEnabled),

    .FAstrobe(FAstrobe),
    .auReset(auReset),
    .sysStatusStrobe(sysStatusStrobe),
    .sysStatusCode(sysStatusCode),
    .sysTimeoutStrobe(sysTimeoutStrobe),

    .fofbDSPreadoutAddress(readoutAddress),
    .fofbDSPreadoutX(readoutX),
    .fofbDSPreadoutY(readoutY),
    .fofbDSPreadoutS(readoutS),
    .fofbDSPreadoutPresent(readoutPresent),

    .uBreadoutStrobe(uBreadoutStrobe),
    .uBreadoutX(uBreadoutX),
    .uBreadoutY(uBreadoutY),
    .uBreadoutS(uBreadoutS),

    .auClk(auClk),
    .auFAstrobe(auFAstrobe),
    .auCCWcellInhibit(auCCWcellInhibit),
    .auCWcellInhibit(auCWcellInhibit),

    .auCellCCWlinkTVALID(auCellCCWlinkTVALID),
    .auCellCCWlinkTLAST(auCellCCWlinkTLAST),
    .auCellCCWlinkTDATA(auCellCCWlinkTDATA),

    .auCellCWlinkTVALID(auCellCWlinkTVALID),
    .auCellCWlinkTLAST(auCellCWlinkTLAST),
    .auCellCWlinkTDATA(auCellCWlinkTDATA)
);

readoutStream #(
    .ADDR_WIDTH(FOFB_INDEX_WIDTH),
    .DATA_WIDTH(96)
) fmpsReadoutStream (
    .clk(sysClk),
    .readoutActive(csr[31]),
    .readoutValid(csr[30]),
    .reset(1'b0),

    .readoutPresent(readoutPresent),
    .readoutAddress(readoutAddress),
    .readoutData(fofbReadout),

    .packetIndex(fofbDSPreadoutIndex),
    .packetData(fofbData),
    .packetValid(fofbDSPreadoutValid)
);

endmodule