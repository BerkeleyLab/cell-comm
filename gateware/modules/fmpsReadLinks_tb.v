`timescale 1ns / 100ps

module fmpsReadLinks_tb #(
    parameter CSR_DATA_BUS_WIDTH = 32,
    parameter CSR_STROBE_BUS_WIDTH = 1
);

reg module_done = 0;
reg fail = 0;
integer errors = 0;
initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("fmpsReadLinks.vcd");
        $dumpvars(0, fmpsReadLinks_tb);
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
    for (sysCc = 0; sysCc < 3000; sysCc = sysCc+1) begin
        sysClk = 0; #5;
        sysClk = 1; #5;
    end
end

integer cc;
reg auClk = 0;
initial begin
    auClk = 0;
    for (cc = 0; cc < 4000; cc = cc+1) begin
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

//////////////////////////////////////////////////////////////
// Testbench
//////////////////////////////////////////////////////////////

// Packet format
localparam DATA_MAGIC_WIDTH                        = 16;
localparam [DATA_MAGIC_WIDTH-1:0] DATA_MAGIC       = 'hCACA;
localparam  MAGIC_WIDTH                            = 16;
localparam  MAGIC_START_BIT                        = 16;
localparam  INDEX_WIDTH                            = 5;
localparam  INDEX_START_BIT                        = 10;
localparam  NUM_DATA_WORDS                         = 1;
localparam real TREADY_PROB                        = 0.5;
localparam FMPS_COUNT_WIDTH                        = INDEX_WIDTH + 1;

localparam [MAGIC_WIDTH-1:0] EXPECTED_HEADER_MAGIC = 16'hB6CF;

//
// Register offsets
//
localparam WR_REG_OFFSET_CSR                   = 0;

//
// Write CSR fields
//
localparam WR_W_CSR_FMPS_COUNT_MASK            = 2**FMPS_COUNT_WIDTH-1;
localparam WR_W_CSR_FMPS_CCW_INHIBIT           = 3*FMPS_COUNT_WIDTH;
localparam WR_W_CSR_FMPS_CW_INHIBIT            = 3*FMPS_COUNT_WIDTH+1;

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

// generate FA strobe every few clock cycles
localparam STROBE_CNT_MAX = 400;
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

// Number of FMPS packets per cycle
localparam NUM_FMPS_PKTS_PER_CYCLE = 8;

always @(posedge auClk) begin
    // generate FMPS packets every cycle
    if (auFAStrobe) begin
        genStrobe(NUM_FMPS_PKTS_PER_CYCLE, 16);
    end
end

//////////////////////////////////////////////////////////////
// FMPS test data streamer
//////////////////////////////////////////////////////////////

localparam NUM_FMPS_GENERATORS = 2;
wire  [31:0] FMPS_TEST_AXI_STREAM_TX_tdata[0:NUM_FMPS_GENERATORS-1];
wire         FMPS_TEST_AXI_STREAM_TX_tvalid[0:NUM_FMPS_GENERATORS-1];
wire         FMPS_TEST_AXI_STREAM_TX_tlast[0:NUM_FMPS_GENERATORS-1];
wire         FMPS_TEST_AXI_STREAM_TX_tready[0:NUM_FMPS_GENERATORS-1];

generate for(i = 0; i < NUM_FMPS_GENERATORS; i = i + 1) begin

wire [31:0] sysFMPSCSR;
assign sysFMPSCSR[31:29] = 0;
assign sysFMPSCSR[28:24] = i*NUM_FMPS_PKTS_PER_CYCLE;
assign sysFMPSCSR[23:0] = 0;

writeFMPSTestLink #(
    .WITH_MULT_PACK_SUPPORT("true")
)
  packetGen (
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

end
endgenerate

wire [(1<<INDEX_WIDTH)-1:0] rxBitmap;
wire [(1<<INDEX_WIDTH)-1:0] fmpsEnabledBitmap;
wire fmpsEnabled;
wire sysStatusStrobe;
wire [2:0] sysStatusCode;
wire sysTimeoutStrobe;
reg [INDEX_WIDTH-1:0] fmpsReadoutAddress = 0;
wire [31:0] fmpsReadout;
reg uBreadoutStrobe = 0;
wire [31:0] uBreadout;

wire [31:0] fmps_CSR;
assign GPIO_IN[WR_REG_OFFSET_CSR] = fmps_CSR;

fmpsReadLinks #(
    .INDEX_WIDTH(INDEX_WIDTH),
    .SYSCLK_RATE(100000000)
)
  DUT (
    .sysClk(sysClk),

    .csrStrobe(GPIO_STROBES),
    .GPIO_OUT(GPIO_OUT),
    .csr(fmps_CSR),
    .rxBitmap(rxBitmap),
    .fmpsEnableBitmap(fmpsEnabledBitmap),
    .fmpsEnabled(fmpsEnabled),

    .FAstrobe(auFAStrobe),

    .sysStatusStrobe(sysStatusStrobe),
    .sysStatusCode(sysStatusCode),
    .sysTimeoutStrobe(sysTimeoutStrobe),

    .fmpsReadoutAddress(fmpsReadoutAddress),
    .fmpsReadout(fmpsReadout),

    .uBreadoutStrobe(uBreadoutStrobe),
    .uBreadout(uBreadout),

    .auClk(auClk),
    .auFAstrobe(auFAStrobe),
    .auReset(1'b0),
    .auCCWFMPSInhibit(),
    .auCWFMPSInhibit(),

    // Tap of outgoing FMPS links
    .auFMPSCCWlinkTVALID(FMPS_TEST_AXI_STREAM_TX_tvalid[0]),
    .auFMPSCCWlinkTLAST(FMPS_TEST_AXI_STREAM_TX_tlast[0]),
    .auFMPSCCWlinkTDATA(FMPS_TEST_AXI_STREAM_TX_tdata[0]),

    .auFMPSCWlinkTVALID(FMPS_TEST_AXI_STREAM_TX_tvalid[1]),
    .auFMPSCWlinkTLAST(FMPS_TEST_AXI_STREAM_TX_tlast[1]),
    .auFMPSCWlinkTDATA(FMPS_TEST_AXI_STREAM_TX_tdata[1])
);

assign FMPS_TEST_AXI_STREAM_TX_tready[0] = 1'b1;
assign FMPS_TEST_AXI_STREAM_TX_tready[1] = 1'b1;

/////////////// Dump DPRAM
/////////////integer i = 0;
/////////////initial begin
/////////////    for (i = 0; i < (1<<INDEX_WIDTH)-1; i = i + 1)
/////////////        $dumpvars(0, DUT.dpram[i]);
/////////////end
/////////////
/////////////// Data Packet has the format described in writeFMPSTestLink_tb.v
/////////////// Dissect packet data
/////////////wire FMPS_invalidFMPS2CC = readoutFMPS[31];
/////////////wire FMPS_invalidCC2CC = readoutFMPS[30];
/////////////wire FMPS_reserved = readoutFMPS[29];
/////////////wire [INDEX_WIDTH-1:0] FMPS_dataCounter = readoutFMPS[28:24];
/////////////wire [DATA_MAGIC_WIDTH-1:0] FMPS_dataMagic = readoutFMPS[23:8];
/////////////wire [7:0] FMPS_cycleCounter = readoutFMPS[7:0];
/////////////
/////////////// Test data
/////////////localparam ST_IDLE                   = 0,
/////////////           ST_READ_NEXT_PACKET       = 1,
/////////////           ST_READ_SETTLE            = 2,
/////////////           ST_READ_PACKET            = 3,
/////////////           ST_CHECK_PACKET           = 4,
/////////////           ST_INVALID_PACKET_BITS    = 5,
/////////////           ST_INVALID_RESERVED_BITS  = 6,
/////////////           ST_INVALID_DATA_COUNTER   = 7,
/////////////           ST_INVALID_DATA_MAGIC     = 8,
/////////////           ST_INVALID_CYCLE_COUNTER  = 9,
/////////////           ST_READ_CYCLE_END         = 10,
/////////////           ST_FAIL                   = 11,
/////////////           ST_HALT                   = 12;
/////////////reg [3:0] state = 0;
/////////////reg [INDEX_WIDTH-1:0] dataCounter = 0;
/////////////reg [7:0] cycleCounter = 0;
/////////////wire fmpsPacketPresent = fmpsBitmap[readoutAddress];
/////////////always @(posedge k) begin
/////////////    if (auFAStrobe && state != ST_HALT) begin
/////////////        cycleCounter <= cycleCounter + 1;
/////////////        allFMPSpresent <= 0;
/////////////        state <= ST_IDLE;
/////////////    end
/////////////    else begin
/////////////        case (state)
/////////////        ST_IDLE: begin
/////////////            if (fmpsCounter == NUM_FMPS_PKTS_PER_CYCLE) begin
/////////////                allFMPSpresent <= 1;
/////////////                readoutAddress <= 0;
/////////////                state <= ST_READ_SETTLE;
/////////////            end
/////////////        end
/////////////
/////////////        ST_READ_NEXT_PACKET: begin
/////////////            readoutAddress <= readoutAddress + 1;
/////////////            state <= ST_READ_SETTLE;
/////////////
/////////////            if (readoutAddress == (1<<INDEX_WIDTH)-1) begin
/////////////                readoutAddress <= 0;
/////////////                state <= ST_READ_CYCLE_END;
/////////////            end
/////////////        end
/////////////
/////////////        // Cope with 1 clock cycle latency
/////////////        ST_READ_SETTLE: begin
/////////////            state <= ST_READ_PACKET;
/////////////        end
/////////////
/////////////        ST_READ_PACKET: begin
/////////////            // we have that packet and it's ready to be checked
/////////////            if (fmpsPacketPresent) begin
/////////////                // dataCounter field must be the same as the
/////////////                // FMPS index for this test
/////////////                dataCounter <= readoutAddress;
/////////////                state <= ST_CHECK_PACKET;
/////////////            end else begin
/////////////                state <= ST_READ_NEXT_PACKET;
/////////////            end
/////////////        end
/////////////
/////////////        ST_CHECK_PACKET: begin
/////////////            if (FMPS_invalidFMPS2CC || FMPS_invalidCC2CC) begin
/////////////                state <= ST_INVALID_PACKET_BITS;
/////////////            end
/////////////            else if (FMPS_reserved != 0) begin
/////////////                state <= ST_INVALID_RESERVED_BITS;
/////////////            end
/////////////            else if (FMPS_dataCounter != dataCounter) begin
/////////////                state <= ST_INVALID_DATA_COUNTER;
/////////////            end
/////////////            else if (FMPS_dataMagic != DATA_MAGIC) begin
/////////////                state <= ST_INVALID_DATA_MAGIC;
/////////////            end
/////////////            else if (FMPS_cycleCounter != cycleCounter) begin
/////////////                state <= ST_INVALID_CYCLE_COUNTER;
/////////////            end
/////////////            else begin
/////////////                state <= ST_READ_NEXT_PACKET;
/////////////            end
/////////////        end
/////////////
/////////////        ST_INVALID_PACKET_BITS: begin
/////////////            $display("@%0d: Invalid packet bit: FMPS2CC: %d, CC2CC: %d",
/////////////                $time, FMPS_invalidFMPS2CC, FMPS_invalidFMPS2CC);
/////////////            state <= ST_FAIL;
/////////////        end
/////////////
/////////////        ST_INVALID_RESERVED_BITS: begin
/////////////            $display("@%0d: Invalid reserved bit: reserved: %d",
/////////////                $time, FMPS_reserved);
/////////////            state <= ST_FAIL;
/////////////        end
/////////////
/////////////        ST_INVALID_DATA_COUNTER: begin
/////////////            $display("@%0d: Invalid data counter: dataCounter: %d, expected: %d",
/////////////                $time, FMPS_dataCounter, dataCounter);
/////////////            state <= ST_FAIL;
/////////////        end
/////////////
/////////////        ST_INVALID_DATA_MAGIC: begin
/////////////            $display("@%0d: Invalid data magic: dataMagic: 0x%04X, expected: 0x%04X",
/////////////                $time, FMPS_dataMagic, DATA_MAGIC);
/////////////            state <= ST_FAIL;
/////////////        end
/////////////
/////////////        ST_INVALID_CYCLE_COUNTER: begin
/////////////            $display("@%0d: Invalid cycle counter: cycleCounter: %d, expected: %d",
/////////////                $time, FMPS_cycleCounter, cycleCounter);
/////////////            state <= ST_FAIL;
/////////////        end
/////////////
/////////////        // Wait until reset. This cycle was good
/////////////        ST_READ_CYCLE_END: ;
/////////////
/////////////        ST_FAIL: begin
/////////////            $display("@%0d: Failed data packet[%d]: 0x%08X", $time, readoutAddress,
/////////////                readoutFMPS);
/////////////            fail <= 1;
/////////////            state <= ST_HALT;
/////////////        end
/////////////
/////////////        ST_HALT: ;
/////////////
/////////////        default: ;
/////////////
/////////////        endcase
/////////////    end
/////////////end

// stimulus

// stimulus
initial begin
    wait(CSR0.ready);
    @(posedge sysClk);

    CSR0.write32(WR_REG_OFFSET_CSR,
        NUM_FMPS_GENERATORS*NUM_FMPS_PKTS_PER_CYCLE);
    @(posedge sysClk);
end

initial begin
    @(posedge auClk);
    module_ready = 1;

    repeat (20)
        @(posedge auClk);

    auChannelUp = 1;
    @(posedge auClk);

    repeat (2000)
        @(posedge auClk);

    module_done = 1;
end

endmodule
