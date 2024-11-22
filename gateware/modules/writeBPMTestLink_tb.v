`timescale 1ns / 100ps

module writeBPMTestLink_tb;

reg module_done = 0;
reg fail = 0;
integer errors = 0;
integer idx = 0;
initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("writeBPMTestLink.vcd");
        $dumpvars(0, writeBPMTestLink_tb);
    end

    wait(module_done);

	if (fail) begin
		$display("FAIL");
		$stop(0);
	end else begin
		$display("PASS");
		$finish(0);
	end
end

integer sysCc;
reg sysClk = 0;
initial begin
    sysClk = 0;
    for (sysCc = 0; sysCc < 1000; sysCc = sysCc+1) begin
        sysClk = 0; #5;
        sysClk = 1; #5;
    end
end

integer cc;
reg auClk = 0;
initial begin
    auClk = 0;
    for (cc = 0; cc < 1000; cc = cc+1) begin
        auClk = 1; #5;
        auClk = 0; #5;
    end
end

reg module_ready = 0;
reg auChannelUp = 0;

wire  [31:0] BPM_TEST_AXI_STREAM_TX_tdata;
wire         BPM_TEST_AXI_STREAM_TX_tvalid;
wire         BPM_TEST_AXI_STREAM_TX_tlast;
wire         BPM_TEST_AXI_STREAM_TX_tready;

// generate FA strobe every few clock cycles
localparam STROBE_CNT_MAX = 200;
localparam STROBE_CNT_WIDTH = $clog2(STROBE_CNT_MAX+1);

reg auFAStrobe = 0;
reg [STROBE_CNT_WIDTH-1:0] strobeCnt = 0;
always @(posedge auClk) begin
    if (!module_ready) begin
        strobeCnt <= 0;
        auFAStrobe <= 0;
    end
    else begin
        strobeCnt <= strobeCnt + 1;
        auFAStrobe <= 0;

        if (strobeCnt == STROBE_CNT_MAX) begin
            strobeCnt <= 0;
            auFAStrobe <= 1;
        end

    end
end

//
// BPM test data streamer
//
wire [31:0] sysBPMCSR;
assign sysBPMCSR[31:29] = 0;
assign sysBPMCSR[28:24] = 1;
assign sysBPMCSR[23:0] = 0;

// Packet format
localparam MAGIC_WIDTH = 16;
localparam MAGIC_START_BIT = 16;
localparam INDEX_WIDTH = 5;
localparam INDEX_START_BIT = 10;
localparam NUM_DATA_WORDS = 3;
localparam real TREADY_PROB = 0.5;

localparam [MAGIC_WIDTH-1:0] EXPECTED_HEADER_MAGIC = 16'hA5BE;

writeBPMTestLink #()
  DUT(
    .sysClk(sysClk),
    .sysBPMCSR(sysBPMCSR),

    .auroraUserClk(auClk),
    .auroraFAstrobe(auFAStrobe),
    .auroraChannelUp(auChannelUp),

    // BPM links
    .BPM_TEST_AXI_STREAM_TX_tdata(BPM_TEST_AXI_STREAM_TX_tdata),
    .BPM_TEST_AXI_STREAM_TX_tvalid(BPM_TEST_AXI_STREAM_TX_tvalid),
    .BPM_TEST_AXI_STREAM_TX_tlast(BPM_TEST_AXI_STREAM_TX_tlast),
    .BPM_TEST_AXI_STREAM_TX_tready(BPM_TEST_AXI_STREAM_TX_tready)
);

wire                         statusStrobe;
wire [1:0]                   statusCode;
wire                         packetStrobe;
wire [INDEX_WIDTH-1:0]       packetIndex;
wire [32*NUM_DATA_WORDS-1:0] packetData;

AXIS2Packet #(
    .MAGIC_WIDTH(MAGIC_WIDTH),
    .MAGIC_START_BIT(MAGIC_START_BIT),
    .INDEX_WIDTH(INDEX_WIDTH),
    .INDEX_START_BIT(INDEX_START_BIT),
    .NUM_DATA_WORDS(NUM_DATA_WORDS),
    .TREADY_PROB(TREADY_PROB)
)
  AXIS2Packet (
    .auroraClk(auClk),
    .newCycleStrobe(auFAStrobe),
    .TVALID(BPM_TEST_AXI_STREAM_TX_tvalid),
    .TLAST(BPM_TEST_AXI_STREAM_TX_tlast),
    .TDATA(BPM_TEST_AXI_STREAM_TX_tdata),
    .TREADY(BPM_TEST_AXI_STREAM_TX_tready),

    .expectedHeaderMagic(EXPECTED_HEADER_MAGIC),

    .statusStrobe(statusStrobe),
    .statusCode(statusCode),

    .packetStrobe(packetStrobe),
    .packetIndex(packetIndex),
    .packetData(packetData)
);

// stimulus
initial begin
    @(posedge auClk);
    module_ready = 1;

    repeat (200)
        @(posedge auClk);

    auChannelUp = 1;
    @(posedge auClk);

    repeat (500)
        @(posedge auClk);

    module_done = 1;
end

endmodule
