// Gather data from Fast MPS (cell controller) loops into DPRAM
module fmpsReadLinks #(
    parameter SYSCLK_RATE       = 100000000,
    parameter INDEX_WIDTH       = 5,
    parameter    FAstrobeDebug  = "false",
    parameter      statusDebug  = "false",
    parameter     rawDataDebug  = "false",
    parameter     ccwLinkDebug  = "false",
    parameter      cwLinkDebug  = "false",
    parameter   FMPSCountDebug  = "false",
    parameter  readoutDebug  = "false"
    ) (
    input  wire        sysClk,

    // Control/Status
    input wire                                                   csrStrobe,
    input wire                                            [31:0] GPIO_OUT,
    (*mark_debug=statusDebug*) output wire                [31:0] csr,
    (*mark_debug=statusDebug*) output reg [(1<<INDEX_WIDTH)-1:0] fmpsBitmapAllFASnapshot,
    (*mark_debug=statusDebug*) output reg [(1<<INDEX_WIDTH)-1:0] fmpsEnableBitmapFASnapshot,

    (*mark_debug=statusDebug*) output reg [(1<<INDEX_WIDTH)-1:0] fmpsBitmapAll,
    (*mark_debug=statusDebug*) output reg [(1<<INDEX_WIDTH)-1:0] fmpsBitmapEnabled,
    (*mark_debug=statusDebug*) output reg                        fmpsEnabled,

    // Synchronization
    (*mark_debug=FAstrobeDebug*) input  wire FAstrobe,

    // Link statistics
    (*mark_debug=statusDebug*) output wire       sysStatusStrobe,
    (*mark_debug=statusDebug*) output wire [2:0] sysStatusCode,
    (*mark_debug=statusDebug*) output reg        sysTimeoutStrobe = 0,

    // Data Readout, mostly for debug/checking. The FMPS data is
    // actually used by the Mitigation Node
    (*mark_debug=readoutDebug*)
    input wire      [INDEX_WIDTH-1:0] fmpsReadoutAddress,
    (*mark_debug=readoutDebug*)
    output wire                [31:0] fmpsReadout,

    // Values to microBlaze
    input  wire                       uBreadoutStrobe,
    output wire                [31:0] uBreadout,

    // Start of Aurora user clock domain nets
    input  wire                              auClk,
    (*mark_debug=FAstrobeDebug*) input  wire auFAstrobe,
    input  wire                              auReset,
    output reg                               auCCWfmpsInhibit = 0,
    output reg                               auCWfmpsInhibit = 0,

    // Tap of outgoing FMPS links
    (*mark_debug=rawDataDebug*) input  wire        auFMPSCCWlinkTVALID,
    (*mark_debug=rawDataDebug*) input  wire        auFMPSCCWlinkTLAST,
    (*mark_debug=rawDataDebug*) input  wire [31:0] auFMPSCCWlinkTDATA,

    (*mark_debug=rawDataDebug*) input  wire        auFMPSCWlinkTVALID,
    (*mark_debug=rawDataDebug*) input  wire        auFMPSCWlinkTLAST,
    (*mark_debug=rawDataDebug*) input  wire [31:0] auFMPSCWlinkTDATA);

parameter FMPS_COUNT_WIDTH = INDEX_WIDTH+1;
localparam READOUT_TIMER_WIDTH = 5;

//
// Control register
//
reg ccwInhibit = 0, cwInhibit = 0;
reg [FMPS_COUNT_WIDTH-1:0] FMPSCount = 0;
reg readoutActive = 0, readoutValid = 0, readTimeout = 0;
reg auReadoutValid_m, auReadoutValid;
always @(posedge sysClk) begin
    if (csrStrobe) begin
        FMPSCount <= GPIO_OUT[0+:FMPS_COUNT_WIDTH];
        ccwInhibit <= GPIO_OUT[3*FMPS_COUNT_WIDTH+0];
        cwInhibit <= GPIO_OUT[3*FMPS_COUNT_WIDTH+1];
    end
end

//
// Packet reception
//
wire       auCCWstatusStrobe, auCWstatusStrobe;
wire       auCCWstatusFMPSenabled, auCWstatusFMPSenabled;
wire [1:0] auCCWstatusCode, auCWstatusCode;
wire [INDEX_WIDTH-1:0] auCCWFMPSindex, auCWFMPSindex;
wire [(1<<INDEX_WIDTH)-1:0] auCCW_FMPSbitmap, auCW_FMPSbitmap;
(* mark_debug = FMPSCountDebug *)
wire [FMPS_COUNT_WIDTH-1:0] auCCWpacketCounter, auCWpacketCounter;
wire                 [31:0] ccwData, cwData;
fmpsReadLink #(
    .INDEX_WIDTH(INDEX_WIDTH),
    .dbg(ccwLinkDebug)
) readCCW (
    .auroraClk(auClk),
    .FAstrobe(auFAstrobe),
    .allFMPSpresent(auReadoutValid),
    .TVALID(auFMPSCCWlinkTVALID),
    .TLAST(auFMPSCCWlinkTLAST),
    .TDATA(auFMPSCCWlinkTDATA),
    .statusStrobe(auCCWstatusStrobe),
    .statusCode(auCCWstatusCode),
    .statusFMPSenabled(auCCWstatusFMPSenabled),
    .statusFMPSindex(auCCWFMPSindex),
    .fmpsCounter(auCCWpacketCounter),
    .fmpsBitmap(auCCW_FMPSbitmap),
    .sysClk(sysClk),
    .readoutAddress(fmpsReadoutAddress),
    .readoutFMPS(ccwData));
fmpsReadLink #(
    .INDEX_WIDTH(INDEX_WIDTH),
    .dbg(cwLinkDebug)
) readCW (
    .auroraClk(auClk),
    .FAstrobe(auFAstrobe),
    .allFMPSpresent(auReadoutValid),
    .TVALID(auFMPSCWlinkTVALID),
    .TLAST(auFMPSCWlinkTLAST),
    .TDATA(auFMPSCWlinkTDATA),
    .statusStrobe(auCWstatusStrobe),
    .statusCode(auCWstatusCode),
    .statusFMPSenabled(auCWstatusFMPSenabled),
    .statusFMPSindex(auCWFMPSindex),
    .fmpsCounter(auCWpacketCounter),
    .fmpsBitmap(auCW_FMPSbitmap),
    .sysClk(sysClk),
    .readoutAddress(fmpsReadoutAddress),
    .readoutFMPS(cwData));

//
// Merge FMPS info from packet reception and get into system clock domain.
//
(* mark_debug = FMPSCountDebug *) wire       mergedTVALID;
(* mark_debug = FMPSCountDebug *) wire [0:0] mergedTUSER;
                                  wire [7:0] mergedTDATA;
wire [INDEX_WIDTH-1:0] mergedFMPSindex = mergedTDATA[0+:INDEX_WIDTH];
wire [1:0]                 mergedStatus = mergedTDATA[INDEX_WIDTH+:2];
wire                       mergedLink = mergedTDATA[INDEX_WIDTH+2];
assign sysStatusStrobe = mergedTVALID;
assign sysStatusCode = { mergedLink, mergedStatus };
wire mergedFMPSenabled = mergedTUSER[0];

localparam LINK_CCW = 1'b0, LINK_CW = 1'b1;
localparam ST_SUCCESS = 2'd0;

fmpsReadLinksMux fmpsReadLinksMux (
    .ACLK(auClk),
    .ARESETN(~auReset),
    .S00_AXIS_ACLK(auClk),
    .S01_AXIS_ACLK(auClk),
    .S00_AXIS_ARESETN(1'b1),
    .S01_AXIS_ARESETN(1'b1),
    .S00_AXIS_TVALID(auCCWstatusStrobe),
    .S00_AXIS_TDATA({LINK_CCW, auCCWstatusCode, auCCWFMPSindex}),
    .S00_AXIS_TUSER(auCCWstatusFMPSenabled),
    .S01_AXIS_TVALID(auCWstatusStrobe),
    .S01_AXIS_TDATA({LINK_CW, auCWstatusCode, auCWFMPSindex}),
    .S01_AXIS_TUSER(auCWstatusFMPSenabled),
    .M00_AXIS_ACLK(sysClk),
    .M00_AXIS_ARESETN(1'b1),
    .M00_AXIS_TVALID(mergedTVALID),
    .M00_AXIS_TREADY(1'b1),
    .M00_AXIS_TDATA(mergedTDATA),
    .M00_AXIS_TUSER(mergedTUSER),
    .S00_ARB_REQ_SUPPRESS(1'b0),
    .S01_ARB_REQ_SUPPRESS(1'b0));

//
// Forward link packet counts to system clock domain
//
reg [FMPS_COUNT_WIDTH-1:0] auCCWpacketCount, auCWpacketCount;
reg [FMPS_COUNT_WIDTH-1:0] ccwPacketCount, cwPacketCount;
reg auPkCountToggle = 0;
(*ASYNC_REG="true"*) reg sysPkCountToggle_m = 0;
reg sysPkCountToggle = 0, sysPkCountToggle_d = 0;
always @(posedge auClk) begin
    if (auFAstrobe) begin
        auCCWpacketCount <= auCCWpacketCounter;
        auCWpacketCount <= auCWpacketCounter;
        auPkCountToggle <= !auPkCountToggle;
    end
end
always @(posedge sysClk) begin
    sysPkCountToggle_m <= auPkCountToggle;
    sysPkCountToggle   <= sysPkCountToggle_m;
    sysPkCountToggle_d <= sysPkCountToggle;
    if (sysPkCountToggle != sysPkCountToggle_d) begin
        sysPkCountToggle_d <= !sysPkCountToggle_d;
        ccwPacketCount <= auCCWpacketCount;
        cwPacketCount <= auCWpacketCount;
    end
end

//
// Keep track of the FMPSs to which we've sent valid data.
// When we've sent data from all FMPSs mark the readout as valid.
//
localparam SEQNO_WIDTH = 3;
(* mark_debug = FMPSCountDebug *)
reg [FMPS_COUNT_WIDTH-1:0] fmpsCounter, fmpsEnabledCounter;
reg [SEQNO_WIDTH-1:0] seqno = 0;
reg [$clog2(SYSCLK_RATE/1000000)-1:0] usDivider;
reg [READOUT_TIMER_WIDTH-1:0] readoutTime, readoutTimer;
(* mark_debug = FMPSCountDebug *) reg timeoutToggle = 0, timeoutToggle_d = 0;
reg timeoutFlag;
always @(posedge sysClk) begin
    timeoutToggle_d <= timeoutToggle;
    sysTimeoutStrobe <= (timeoutToggle != timeoutToggle_d);
    if (FAstrobe) begin
        fmpsCounter <= 0;
        fmpsEnabledCounter <= 0;
        fmpsBitmapAll <= 0;
        fmpsBitmapEnabled <= 0;
        readoutActive <= 1;
        readoutValid <= 0;
        usDivider <= ((SYSCLK_RATE/1000000)/2)-1;
        readoutTimer <= 0;
        readTimeout <= 0;
        timeoutFlag <= 0;
        fmpsBitmapAllFASnapshot <= fmpsBitmapAll;
        fmpsEnableBitmapFASnapshot <= fmpsBitmapEnabled;
    end
    else if (readoutActive) begin
        if (fmpsCounter == FMPSCount) begin
            fmpsEnabled <= (fmpsEnabledCounter == FMPSCount);
            seqno <= seqno + 1;
            readoutValid <= 1;
            readoutTime <= readoutTimer;
            readoutActive <= 0;
        end
        else if (timeoutFlag) begin
            fmpsEnabled <= 0;
            readTimeout <= 1;
            timeoutToggle <= !timeoutToggle;
            readoutTime <= readoutTimer;
            readoutActive <= 0;
        end
        if (mergedTVALID && (mergedStatus == ST_SUCCESS)) begin
            // Mark all the FMPS nodes that we've received data,
            // regardless if it's enabled or not
            fmpsBitmapAll[mergedFMPSindex] <= 1;
            if (!fmpsBitmapAll[mergedFMPSindex]) begin
                fmpsCounter <= fmpsCounter + 1;
            end

            // Mark only the FMPS nodes that are enabled
            if (mergedFMPSenabled) begin
                fmpsBitmapEnabled[mergedFMPSindex] <= 1;
                if (!fmpsBitmapEnabled[mergedFMPSindex]) begin
                    fmpsEnabledCounter <= fmpsEnabledCounter + 1;
                end
            end
        end
        if (usDivider == 0) begin
            readoutTimer <= readoutTimer + 1;
            usDivider <= SYSCLK_RATE/1000000-1;
            if (readoutTimer == {READOUT_TIMER_WIDTH{1'b1}}) begin
                timeoutFlag <= 1;
            end
        end
        else begin
            usDivider <= usDivider - 1;
        end
    end
end

//
// Keep track of which buffers contain valid data from a particular FMPS.
//
(*ASYNC_REG="true"*) reg auCCWfmpsInhibit_m, auCWfmpsInhibit_m;
always @(posedge auClk)begin
    auReadoutValid_m <= readoutValid;
    auReadoutValid   <= auReadoutValid_m;
    auCCWfmpsInhibit_m <= ccwInhibit;
    auCWfmpsInhibit_m  <= cwInhibit;
    if (auFAstrobe) begin
        auCCWfmpsInhibit <= auCCWfmpsInhibit_m;
        auCWfmpsInhibit  <= auCWfmpsInhibit_m;
    end
end

//
// Data readout
// Yes, we are using the 'au' clock domain bitmaps in the system clock domain,
// but that's acceptable since the Data readout occurs only after the bitmaps
// have been modified.
//
(*mark_debug=readoutDebug*) reg ccwHasFMPS, cwHasFMPS;
always @(posedge sysClk) begin
    // The one cycle latency in extracting the bit from the bitmap matches the
    // one cycle latency to read the values from the 'readLink' DPRAM.
    ccwHasFMPS <= readoutValid && auCCW_FMPSbitmap[fmpsReadoutAddress];
    cwHasFMPS <= readoutValid && auCW_FMPSbitmap[fmpsReadoutAddress];
end
assign fmpsReadout = ccwHasFMPS ? ccwData : (cwHasFMPS ? cwData : 0);

//
// MicroBlaze status
//
assign csr = { readoutActive, readoutValid, readoutTime, seqno,
            {32-2-READOUT_TIMER_WIDTH-SEQNO_WIDTH-3-(3*FMPS_COUNT_WIDTH){1'b0}},
                                     1'b0, cwInhibit, ccwInhibit,
                                     cwPacketCount, ccwPacketCount, FMPSCount };

//
// MicroBlaze readout DPRAM
// Use for diagnostic printout
//
reg [31:0] uBdpram [0:(1<<INDEX_WIDTH)-1];
reg [31:0] uBq = 0;
reg [INDEX_WIDTH-1:0] fmpsReadoutAddress_d = 0;
wire fmpsReadoutValid=(fmpsReadoutAddress[0]!=fmpsReadoutAddress_d[0]);
assign uBreadout=uBq;
reg [INDEX_WIDTH-1:0] uBreadoutAddress;
always @(posedge sysClk) begin
    fmpsReadoutAddress_d <= fmpsReadoutAddress;

    if (uBreadoutStrobe)
        uBreadoutAddress <= GPIO_OUT[INDEX_WIDTH-1:0];

    uBq <= uBdpram[uBreadoutAddress];
    if (fmpsReadoutValid) begin
        uBdpram[fmpsReadoutAddress_d] <= fmpsReadout;
    end
end

endmodule
