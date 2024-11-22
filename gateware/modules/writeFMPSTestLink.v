//
// Write dummy FMPS packets for testing purposes.
// Nets with names beginning with 'sys' are in the system clock domain.
// All other nets are in the Aurora user clock domain.
//
module writeFMPSTestLink #(
    parameter faStrobeDebug    = "false",
    parameter stateDebug       = "false",
    parameter testInDebug      = "false") (

    input wire         sysClk,
    input wire [31:0]  sysFMPSCSR,

    // Start of Aurora user clock domain nets
    input  wire         auroraUserClk,

    // Marker for beginning of data transfer session
    (* mark_debug = faStrobeDebug *)
    input  wire         auroraFAstrobe,
    input  wire         auroraChannelUp,

    // FMPS links
    (* mark_debug = testInDebug *)
    output  wire  [31:0] FMPS_TEST_AXI_STREAM_TX_tdata,
    (* mark_debug = testInDebug *)
    output  wire         FMPS_TEST_AXI_STREAM_TX_tvalid,
    (* mark_debug = testInDebug *)
    output  wire         FMPS_TEST_AXI_STREAM_TX_tlast,
    (* mark_debug = testInDebug *)
    input  wire         FMPS_TEST_AXI_STREAM_TX_tready,
    output wire         TESTstatusStrobe,
    output wire  [1:0]  TESTstatusCode,
    output wire  [2:0]  dbgFwState
);

localparam MAX_FMPSS          = 32;
parameter FMPS_COUNT_WIDTH    = $clog2(MAX_FMPSS + 1);
parameter FMPS_INDEX_WIDTH    = $clog2(MAX_FMPSS);

assign TESTstatusStrobe = 0;
assign TESTstatusCode = 0;

// Get CSR from FMPS
wire [31:0] auFMPSCSR;
forwardData #(
    .DATA_WIDTH(32)
  )
  forwardCmd(
    .inClk(sysClk),
    .inData(sysFMPSCSR),
    .outClk(auroraUserClk),
    .outData(auFMPSCSR));

wire [FMPS_INDEX_WIDTH-1:0] auCsrCellIndex = auFMPSCSR[24+:FMPS_INDEX_WIDTH];

// Forwarded values
wire FMPSenabled = 1;
wire [31:0] txHeader = {
                16'hB6CF,
                FMPSenabled,
                {6-1-FMPS_INDEX_WIDTH{1'b0}}, auCsrCellIndex,
                {10{1'b0}}};
reg [31:0] txData = 0;

localparam FIFO_AW = 3;
localparam FIFO_USERW = 1;
localparam FIFO_DATAW = 32;
localparam FIFO_DW = FIFO_USERW + FIFO_DATAW;
localparam FIFO_MAX = 2**FIFO_AW-1;

reg [FIFO_USERW-1:0] fifoUserIn = 0;
reg [FIFO_DATAW-1:0] fifoDataIn = 0;
wire [FIFO_DW-1:0] fifoIn = {fifoUserIn, fifoDataIn};
reg fifoWe = 0;
reg fifoForceRe = 0;
wire [FIFO_DW-1:0] fifoOut;
wire [FIFO_USERW-1:0] fifoUserOut;
wire [FIFO_DATAW-1:0] fifoDataOut;
wire fifoRe;
wire fifoFull, fifoEmpty;
wire signed [FIFO_AW:0] fifoCount;
genericFifo #(
    .aw(FIFO_AW),
    .dw(FIFO_DW),
    .fwft(1))
fifo (
    .clk(auroraUserClk),

    .din(fifoIn),
    .we(fifoWe),

    .dout(fifoOut),
    .re(fifoRe),

    .full(fifoFull),
    .empty(fifoEmpty),

    .count(fifoCount)
);

assign {fifoUserOut, fifoDataOut} = fifoOut;

wire fifoValid = !(fifoEmpty || fifoForceRe);
wire fifoAlmostFull = (fifoCount >= FIFO_MAX-2);

assign fifoRe = (fifoValid && FMPS_TEST_AXI_STREAM_TX_tready) || fifoForceRe;
assign FMPS_TEST_AXI_STREAM_TX_tdata = fifoDataOut;
assign FMPS_TEST_AXI_STREAM_TX_tlast = fifoUserOut;
assign FMPS_TEST_AXI_STREAM_TX_tvalid = fifoValid;

// Data forwarding state machine
localparam FWST_IDLE          = 0,
           FWST_EMPTY_FIFO    = 1,
           FWST_PUSH_HEADER   = 2,
           FWST_PUSH_DATA     = 3;
(* mark_debug = stateDebug *) reg  [2:0] fwState = FWST_IDLE;
assign dbgFwState = fwState;
reg [7:0] FAcycleCounter = 0;
always @(posedge auroraUserClk) begin
    if (auroraFAstrobe) begin
        // Start a new readout session
        FAcycleCounter <= FAcycleCounter + 1;
        fwState <= FWST_EMPTY_FIFO;
    end
    else begin
        fifoWe <= 0;

        case (fwState)
        FWST_IDLE: begin
        end

        FWST_EMPTY_FIFO: begin
            if (!fifoEmpty) begin
                fifoForceRe <= 1;
            end
            else begin
                fifoForceRe <= 0;
                if (auroraChannelUp) begin
                    fwState <= FWST_PUSH_HEADER;
                end
            end
        end

        FWST_PUSH_HEADER: begin
            if (!fifoAlmostFull) begin
                fifoWe <= 1;
                fifoDataIn <= txHeader;
                fifoUserIn <= 0;

                // bit 31 and 30 have special meaning
                txData  <= {1'b0, 1'b0, {6{1'b0}}, 16'hCACA, FAcycleCounter};
                fwState <= FWST_PUSH_DATA;
            end
        end

        FWST_PUSH_DATA: begin
            if (!fifoAlmostFull) begin
                fifoWe <= 1;
                fifoDataIn <= txData;
                fifoUserIn <= 1;
                fwState <= FWST_IDLE;
            end
        end

        default: ;
        endcase
    end
end

endmodule
