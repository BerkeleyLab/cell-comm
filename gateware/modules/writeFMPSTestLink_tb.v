`timescale 1ns / 100ps

module writeFMPSTestLink_tb #(
    parameter CSR_DATA_BUS_WIDTH = 32,
    parameter CSR_STROBE_BUS_WIDTH = 1
);

reg module_done = 0;
reg fail = 0;
integer errors = 0;
integer idx = 0;
initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("writeFMPSTestLink.vcd");
        $dumpvars(0, writeFMPSTestLink_tb);
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

// Packet format
localparam DATA_PATTERN_WIDTH = 16;
localparam [DATA_PATTERN_WIDTH-1:0] DATA_PATTERN = 'hCACA;
localparam MAGIC_WIDTH = 16;
localparam MAGIC_START_BIT = 16;
localparam INDEX_WIDTH = 5;
localparam INDEX_START_BIT = 10;
localparam NUM_DATA_WORDS = 1;
localparam real TREADY_PROB = 0.5;

localparam [MAGIC_WIDTH-1:0] EXPECTED_HEADER_MAGIC = 16'hB6CF;

//
// Register offsets
//
localparam WR_REG_OFFSET_CSR                    = 0;

//
// Write CSR fields
//
localparam WR_RW_CSR_FMPS_INDEX_SHIFT          = 24;
localparam WR_RW_CSR_FMPS_INDEX_MASK           = (1<<INDEX_WIDTH)-1;

//////////////////////////////////////////////////////////////
// CSR
//////////////////////////////////////////////////////////////

csrTestMaster # (
    .CSR_DATA_BUS_WIDTH(CSR_DATA_BUS_WIDTH),
    .CSR_STROBE_BUS_WIDTH(CSR_STROBE_BUS_WIDTH)
) CSR0 (
    .clk(sysClk)
);

wire [CSR_DATA_BUS_WIDTH-1:0] GPIO_IN[0:CSR_STROBE_BUS_WIDTH-1];
wire [CSR_STROBE_BUS_WIDTH-1:0] GPIO_STROBES = CSR0.csr_stb_o;
wire [CSR_DATA_BUS_WIDTH-1:0] GPIO_OUT = CSR0.csr_data_o;

genvar i;
generate for(i = 0; i < CSR_STROBE_BUS_WIDTH; i = i + 1) begin
    assign CSR0.csr_data_i[(i+1)*CSR_DATA_BUS_WIDTH-1:i*CSR_DATA_BUS_WIDTH] = GPIO_IN[i];
end
endgenerate

reg module_ready = 0;
reg auChannelUp = 0;

wire  [31:0] FMPS_TEST_AXI_STREAM_TX_tdata;
wire         FMPS_TEST_AXI_STREAM_TX_tvalid;
wire         FMPS_TEST_AXI_STREAM_TX_tlast;
wire         FMPS_TEST_AXI_STREAM_TX_tready;

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
    // generate 8 FMPS packets
    if (auFAStrobe) begin
        genStrobe(8, 8);
    end
end

//
// FMPS test data streamer
//
wire [31:0] sysCsr;

writeFMPSTestLink #(
    .INDEX_WIDTH(INDEX_WIDTH),
    .WITH_MULT_PACK_SUPPORT("true"),
    .DATA_PATTERN(DATA_PATTERN)
)
  DUT(
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES),
    .GPIO_OUT(GPIO_OUT),
    .sysCsr(sysCsr),

    .auroraUserClk(auClk),
    .genPacketStrobe(genPacketStrobe),
    .auroraFAstrobe(auFAStrobe),
    .auroraChannelUp(auChannelUp),

    // FMPS links
    .FMPS_TEST_AXI_STREAM_TX_tdata(FMPS_TEST_AXI_STREAM_TX_tdata),
    .FMPS_TEST_AXI_STREAM_TX_tvalid(FMPS_TEST_AXI_STREAM_TX_tvalid),
    .FMPS_TEST_AXI_STREAM_TX_tlast(FMPS_TEST_AXI_STREAM_TX_tlast),
    .FMPS_TEST_AXI_STREAM_TX_tready(FMPS_TEST_AXI_STREAM_TX_tready)
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
    .TVALID(FMPS_TEST_AXI_STREAM_TX_tvalid),
    .TLAST(FMPS_TEST_AXI_STREAM_TX_tlast),
    .TDATA(FMPS_TEST_AXI_STREAM_TX_tdata),
    .TREADY(FMPS_TEST_AXI_STREAM_TX_tready),

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
wire [INDEX_WIDTH-1:0] FMPS_dataIndex = packetData[28:24];
wire [DATA_PATTERN_WIDTH-1:0] FMPS_dataPattern = packetData[23:8];
wire [7:0] FMPS_cycleCounter = packetData[7:0];

// Test data
localparam ST_IDLE                  = 0,
           ST_CHECK_PACKET          = 1,
           ST_MALFORMED_PACKET      = 2,
           ST_INVALID_PACKET_BITS   = 3,
           ST_INVALID_RESERVED_BITS = 4,
           ST_INVALID_DATA_INDEX    = 5,
           ST_INVALID_DATA_PATTERN  = 6,
           ST_INVALID_CYCLE_COUNTER = 7,
           ST_FAIL                  = 8,
           ST_HALT                  = 9;
reg [3:0] state = 0;
reg [7:0] cycleCounter = 0;
reg malformedPacket = 0;
reg [1:0] statusCode_r = 0;
always @(posedge auClk) begin
    if (auFAStrobe && state != ST_HALT) begin
        malformedPacket <= 0;
        statusCode_r <= 0;
        state <= ST_IDLE;
        cycleCounter <= cycleCounter + 1;
    end
    else begin
        case (state)
        ST_IDLE: begin
            state <= ST_CHECK_PACKET;
        end

        ST_CHECK_PACKET: begin
            if (malformedPacket) begin
                state <= ST_MALFORMED_PACKET;
            end
            else begin
                if (statusStrobe) begin
                    if (statusCode != 0) begin
                        statusCode_r <= statusCode;
                        malformedPacket <= 1;
                    end
                end

                if (packetStrobe) begin
                    if (FMPS_invalidFMPS2CC || FMPS_invalidCC2CC) begin
                        state <= ST_INVALID_PACKET_BITS;
                    end
                    else if (FMPS_reserved != 0) begin
                        state <= ST_INVALID_RESERVED_BITS;
                    end
                    else if (FMPS_dataIndex != packetIndex) begin
                        state <= ST_INVALID_DATA_INDEX;
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
        end

        ST_MALFORMED_PACKET: begin
            $display("@%0d: Malformed packet: Status code: %d, Expected: 0",
                $time, statusCode_r);
            state <= ST_FAIL;
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

        ST_INVALID_DATA_INDEX: begin
            $display("@%0d: Invalid data index: dataIndex: %d, expected: %d",
                $time, FMPS_dataIndex, packetIndex);
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
integer fmpsIndex = 1;
initial begin
    wait(CSR0.ready);
    @(posedge sysClk);

    CSR0.write32(WR_REG_OFFSET_CSR,
        (fmpsIndex & WR_RW_CSR_FMPS_INDEX_MASK) << WR_RW_CSR_FMPS_INDEX_SHIFT);
    @(posedge sysClk);
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
