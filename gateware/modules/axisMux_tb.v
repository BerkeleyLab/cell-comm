`timescale 1ns / 100ps

module axisMux_tb;

parameter NUM_SOURCES = 4;
parameter NUM_PACKETS_PER_FMPS = 4;

reg module_done = 0;
reg fail = 0;
integer errors = 0;
integer idx = 0;
initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("axisMux.vcd");
        $dumpvars(0, axisMux_tb);
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

//////////////////////////////////////////////////////////
// Clocks
//////////////////////////////////////////////////////////

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
        auClk = 1; #4;
        auClk = 0; #4;
    end
end

//////////////////////////////////////////////////////////
// Functions/Tasks
//////////////////////////////////////////////////////////

reg genPacketStrobe = 0;

task genStrobe;
  input integer numStrobes;
  input integer delay;
begin : gen_strobe
    repeat (numStrobes) begin
        repeat (delay)
            @(posedge auClk);

        genPacketStrobe <= 1'b1;
        @(posedge auClk);
        genPacketStrobe <= 1'b0;
    end
end
endtask // gen_strobe

//////////////////////////////////////////////////////////
// Testbench
//////////////////////////////////////////////////////////

reg module_ready = 0;
reg auChannelUp = 0;

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

always @(posedge auClk) begin
    // generate FMPS packets
    if (auFAStrobe) begin
        genStrobe(NUM_PACKETS_PER_FMPS, 8);
    end
end

wire sysFAStrobe;
pulseSync pulseSync (
    .s_clk(auClk),
    .s_pulse(auFAStrobe),

    .d_clk(sysClk),
    .d_pulse(sysFAStrobe)
);

//
// FMPS test data streamer
//
// Packet format
localparam DATA_WIDTH = 32;
localparam USER_WIDTH = 1;
localparam DATA_PATTERN_WIDTH = 16;
localparam [DATA_PATTERN_WIDTH-1:0] DATA_PATTERN = 'hCACA;
localparam MAGIC_WIDTH = 16;
localparam MAGIC_START_BIT = 16;
localparam INDEX_WIDTH = 5;
localparam INDEX_START_BIT = 10;
localparam NUM_DATA_WORDS = 1;
localparam real TREADY_PROB = 0.5;

localparam [MAGIC_WIDTH-1:0] EXPECTED_HEADER_MAGIC = 16'hB6CF;

wire                   FMPS_TEST_AXI_STREAM_TX_clk[0:NUM_SOURCES-1];
wire  [DATA_WIDTH-1:0] FMPS_TEST_AXI_STREAM_TX_tdata[0:NUM_SOURCES-1];
wire  [USER_WIDTH-1:0] FMPS_TEST_AXI_STREAM_TX_tuser[0:NUM_SOURCES-1];
wire                   FMPS_TEST_AXI_STREAM_TX_tvalid[0:NUM_SOURCES-1];
wire                   FMPS_TEST_AXI_STREAM_TX_tlast[0:NUM_SOURCES-1];
wire                   FMPS_TEST_AXI_STREAM_TX_tready[0:NUM_SOURCES-1];

wire  [NUM_SOURCES-1:0]            FMPS_TEST_AXI_STREAM_TX_clk_flatten;
wire  [DATA_WIDTH*NUM_SOURCES-1:0] FMPS_TEST_AXI_STREAM_TX_tdata_flatten;
wire  [USER_WIDTH*NUM_SOURCES-1:0] FMPS_TEST_AXI_STREAM_TX_tuser_flatten;
wire  [NUM_SOURCES-1:0]            FMPS_TEST_AXI_STREAM_TX_tvalid_flatten;
wire  [NUM_SOURCES-1:0]            FMPS_TEST_AXI_STREAM_TX_tlast_flatten;
wire  [NUM_SOURCES-1:0]            FMPS_TEST_AXI_STREAM_TX_tready_flatten;

genvar i;
generate
for (i = 0; i < NUM_SOURCES; i = i + 1) begin

wire [31:0] sysFMPSCSR;
assign sysFMPSCSR[31:29] = 0;
// fmpsIndex start
assign sysFMPSCSR[28:24] = i*NUM_PACKETS_PER_FMPS;
assign sysFMPSCSR[23:0] = 0;

writeFMPSTestLink #(
    .WITH_MULT_PACK_SUPPORT("true"),
    .DATA_PATTERN(DATA_PATTERN)
)
  fmpsDataGen(
    .sysClk(sysClk),
    .sysFMPSCSR(sysFMPSCSR),

    .auroraUserClk(auClk),
    .genPacketStrobe(genPacketStrobe),
    .auroraFAstrobe(auFAStrobe),
    .auroraChannelUp(auChannelUp),

    // FMPS links
    .FMPS_TEST_AXI_STREAM_TX_tdata(FMPS_TEST_AXI_STREAM_TX_tdata[i]),
    .FMPS_TEST_AXI_STREAM_TX_tvalid(FMPS_TEST_AXI_STREAM_TX_tvalid[i]),
    .FMPS_TEST_AXI_STREAM_TX_tlast(FMPS_TEST_AXI_STREAM_TX_tlast[i]),
    .FMPS_TEST_AXI_STREAM_TX_tready(FMPS_TEST_AXI_STREAM_TX_tready[i])
);

assign FMPS_TEST_AXI_STREAM_TX_clk[i] = auClk;
assign FMPS_TEST_AXI_STREAM_TX_tuser[i] = 'h0;

assign FMPS_TEST_AXI_STREAM_TX_clk_flatten[i] = FMPS_TEST_AXI_STREAM_TX_clk[i];
assign FMPS_TEST_AXI_STREAM_TX_tdata_flatten[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] = FMPS_TEST_AXI_STREAM_TX_tdata[i];
assign FMPS_TEST_AXI_STREAM_TX_tuser_flatten[(i+1)*USER_WIDTH-1:i*USER_WIDTH] = FMPS_TEST_AXI_STREAM_TX_tuser[i];
assign FMPS_TEST_AXI_STREAM_TX_tvalid_flatten[i] = FMPS_TEST_AXI_STREAM_TX_tvalid[i];
assign FMPS_TEST_AXI_STREAM_TX_tlast_flatten[i] = FMPS_TEST_AXI_STREAM_TX_tlast[i];
assign FMPS_TEST_AXI_STREAM_TX_tready[i] = FMPS_TEST_AXI_STREAM_TX_tready_flatten[i];

end
endgenerate

wire  [DATA_WIDTH-1:0] AXIS_MUX_tdata;
wire  [USER_WIDTH-1:0] AXIS_MUX_tuser;
wire                   AXIS_MUX_tvalid;
wire                   AXIS_MUX_tlast;
wire                   AXIS_MUX_tready;

axisMux #(
    .FIFO_DEPTH(8),
    .DATA_WIDTH(DATA_WIDTH),
    .USER_WIDTH(USER_WIDTH),
    .NUM_SOURCES(NUM_SOURCES)
    ) DUT (
    .arst(!auChannelUp),

    .s_clk(FMPS_TEST_AXI_STREAM_TX_clk_flatten),
    .s_tvalid(FMPS_TEST_AXI_STREAM_TX_tvalid_flatten),
    .s_tready(FMPS_TEST_AXI_STREAM_TX_tready_flatten),
    .s_tlast(FMPS_TEST_AXI_STREAM_TX_tlast_flatten),
    .s_tdata(FMPS_TEST_AXI_STREAM_TX_tdata_flatten),
    .s_tuser(FMPS_TEST_AXI_STREAM_TX_tuser_flatten),

    .m_clk(sysClk),
    .m_tvalid(AXIS_MUX_tvalid),
    .m_tready(AXIS_MUX_tready),
    .m_tlast(AXIS_MUX_tlast),
    .m_tdata(AXIS_MUX_tdata),
    .m_tuser(AXIS_MUX_tuser)
);

// Check Packet

wire                         statusStrobe;
wire [1:0]                   statusCode;
wire                         packetStrobe;
wire [INDEX_WIDTH-1:0]       packetIndex;
wire [DATA_WIDTH*NUM_DATA_WORDS-1:0] packetData;

AXIS2Packet #(
    .MAGIC_WIDTH(MAGIC_WIDTH),
    .MAGIC_START_BIT(MAGIC_START_BIT),
    .INDEX_WIDTH(INDEX_WIDTH),
    .INDEX_START_BIT(INDEX_START_BIT),
    .NUM_DATA_WORDS(NUM_DATA_WORDS),
    .TREADY_PROB(TREADY_PROB)
)
  AXIS2Packet (
    .auroraClk(sysClk),
    .newCycleStrobe(sysFAStrobe),
    .TVALID(AXIS_MUX_tvalid),
    .TLAST(AXIS_MUX_tlast),
    .TDATA(AXIS_MUX_tdata),
    .TREADY(AXIS_MUX_tready),

    .expectedHeaderMagic(EXPECTED_HEADER_MAGIC),

    .statusStrobe(statusStrobe),
    .statusCode(statusCode),

    .packetStrobe(packetStrobe),
    .packetIndex(packetIndex),
    .packetData(packetData)
);

// Data Packet has the format
// bit
// 31:    invalid FMPS to Cell Controller packet
// 30:    invalid Cell Controller to Cell Controller packet
// 29:    reserved, always 0
// 28-24: monotonic counter, starting at 0
// 23-8:  16'hCACA
// 7-0:   cycle counter, starting at 1
// txData  <= {1'b0, 1'b0,
//     1'b0, fmpsDataCounter,
//     16'hCACA, FAcycleCounter};

// Dissect packet data
wire FMPS_invalidFMPS2CC = packetData[31];
wire FMPS_invalidCC2CC = packetData[30];
wire FMPS_reserved = packetData[29];
wire [INDEX_WIDTH-1:0] FMPS_dataCounter = packetData[28:24];
wire [DATA_PATTERN_WIDTH-1:0] FMPS_dataPattern = packetData[23:8];
wire [7:0] FMPS_cycleCounter = packetData[7:0];

// Test data
localparam ST_IDLE                  = 0,
           ST_CHECK_PACKET          = 1,
           ST_INVALID_PACKET_BITS   = 2,
           ST_INVALID_RESERVED_BITS = 3,
           ST_INVALID_DATA_COUNTER  = 4,
           ST_INVALID_DATA_PATTERN  = 5,
           ST_INVALID_CYCLE_COUNTER = 6,
           ST_FAIL                  = 7,
           ST_HALT                  = 8;
reg [3:0] state = 0;
reg [7:0] cycleCounter = 0;
always @(posedge sysClk) begin
    if (sysFAStrobe && state != ST_HALT) begin
        state <= ST_IDLE;
        cycleCounter <= cycleCounter + 1;
    end
    else begin
        case (state)
        ST_IDLE: begin
            state <= ST_CHECK_PACKET;
        end

        ST_CHECK_PACKET: begin
            if (packetStrobe) begin
                if (FMPS_invalidFMPS2CC || FMPS_invalidCC2CC) begin
                    state <= ST_INVALID_PACKET_BITS;
                end
                else if (FMPS_reserved != 0) begin
                    state <= ST_INVALID_RESERVED_BITS;
                end
                else if (FMPS_dataCounter != packetIndex) begin
                    state <= ST_INVALID_DATA_COUNTER;
                end
                else if (FMPS_dataPattern != DATA_PATTERN) begin
                    state <= ST_INVALID_DATA_PATTERN;
                end
                else if (FMPS_cycleCounter != cycleCounter) begin
                    state <= ST_INVALID_CYCLE_COUNTER;
                end
                else begin
                end
            end
        end

        ST_INVALID_PACKET_BITS: begin
            $display("@%0d: Invalid packet bit: FMPS2CC: %d, CC2CC: %d",
                $time, FMPS_invalidFMPS2CC, FMPS_invalidFMPS2CC);
            state <= ST_FAIL;
        end

        ST_INVALID_RESERVED_BITS: begin
            $display("@%0d: Invalid reserved bit: reserved: %d",
                $time, FMPS_reserved);
            state <= ST_FAIL;
        end

        ST_INVALID_DATA_COUNTER: begin
            $display("@%0d: Invalid data counter: dataCounter: %d, expected: %d",
                $time, FMPS_dataCounter, packetIndex);
            state <= ST_FAIL;
        end

        ST_INVALID_DATA_PATTERN: begin
            $display("@%0d: Invalid data magic: dataPattern: 0x%04X, expected: 0x%04X",
                $time, FMPS_dataPattern, DATA_PATTERN);
            state <= ST_FAIL;
        end

        ST_INVALID_CYCLE_COUNTER: begin
            $display("@%0d: Invalid cycle counter: cycleCounter: %d, expected: %d",
                $time, FMPS_cycleCounter, cycleCounter);
            state <= ST_FAIL;
        end

        ST_FAIL: begin
            $display("@%0d: Failed data packet: 0x%08X", $time, packetData);
            fail <= 1;
            state <= ST_HALT;
        end

        ST_HALT: ;

        default: ;

        endcase
    end
end

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
