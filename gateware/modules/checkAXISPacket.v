// Check if the incoming link looks good
module checkAXISPacket #(
    // header magic number of bits. Always at the
    // MSB in the header
    parameter MAGIC_WIDTH = 16,
    // magic start bit in the header
    parameter MAGIC_START_BIT = 16,
    // index width in the header
    parameter INDEX_WIDTH    = 5,
    // index start bit in the header
    parameter INDEX_START_BIT  = 10,
    // number of 32-bit words in the protocol
    parameter NUM_DATA_WORDS = 1,
    // TREADY probability
    parameter real TREADY_PROB = 0.5
) (
    input  wire        auroraClk,
    input  wire        newCycleStrobe,
    input  wire        TVALID,
    output reg         TREADY,
    input  wire        TLAST,
    input  wire [31:0] TDATA,

    input  wire [MAGIC_WIDTH-1:0] expectedHeaderMagic,

    output wire                     statusStrobe,
    output reg     [1:0]            statusCode,

    output wire                         packetStrobe,
    output reg  [INDEX_WIDTH-1:0]       packetIndex,
    output wire [32*NUM_DATA_WORDS-1:0] packetData
);

////////////////////////////////////////////////////////
// Functions
////////////////////////////////////////////////////////

function automatic f_gen_bit_one;
    input real prob;
    real temp;
begin
    // $random is surronded by the concat operator in order
    // to provide us with only unsigned (bit vector) data.
    // Generates valud in a 0..1 range
    temp = ({$random} % 100 + 1)/100.00;//threshold;

    if (temp <= prob)
        f_gen_bit_one = 1'b1;
    else
        f_gen_bit_one = 1'b0;
end
endfunction

function automatic f_gen_data_rdy_gen;
    input real prob;
begin
    f_gen_data_rdy_gen = f_gen_bit_one(prob);
end
endfunction

////////////////////////////////////////////////////////
// Checks
////////////////////////////////////////////////////////

generate
if (INDEX_START_BIT + INDEX_WIDTH-1 > MAGIC_START_BIT-1) begin
    INDEX_RANGE_conflits_with_HEADER_RANGE();
end
endgenerate

generate
if (NUM_DATA_WORDS < 1) begin
    NUM_DATA_WORDS_cannot_be_smaller_than_1();
end
endgenerate

////////////////////////////////////////////////////////
// Modules
////////////////////////////////////////////////////////

//
// Dissect header
//
wire [MAGIC_WIDTH-1:0] headerMagic   = TDATA[MAGIC_START_BIT+:MAGIC_WIDTH];
wire [INDEX_WIDTH-1:0] headerIndex   = TDATA[INDEX_START_BIT+:INDEX_WIDTH];

//
// Reception statistics
//
localparam ST_SUCCESS    = 2'd0,
           ST_BAD_HEADER = 2'd1,
           ST_BAD_SIZE   = 2'd2;

//
// Reception state machine
//
localparam S_AWAIT_HEADER      = 2'd0,
           S_AWAIT_DATA        = 2'd1,
           S_AWAIT_LAST        = 2'd2;

//
// Data words parameters
//
localparam NUM_DATA_WORDS_WIDTH = $clog2(NUM_DATA_WORDS+1)+1;

reg  [1:0] state = S_AWAIT_HEADER;
reg [31:0] incomingData [0:NUM_DATA_WORDS-1];
reg [NUM_DATA_WORDS_WIDTH-1:0] incomingDataCounter = 0;

reg statusToggle = 0, statusToggle_d = 0;
assign statusStrobe = (statusToggle != statusToggle_d);

reg packetToggle = 0, packetToggle_d = 0;
assign packetStrobe = (packetToggle != packetToggle_d);

reg isNewPacket = 0;

// Generate READY signal with some probability
always @(posedge auroraClk) begin
    TREADY <= f_gen_data_rdy_gen(TREADY_PROB);
end

integer i;
always @(posedge auroraClk) begin
    statusToggle_d <= statusToggle;
    packetToggle_d <= packetToggle;

    if (newCycleStrobe) begin
        for (i = 0; i < NUM_DATA_WORDS; i=i+1)
            incomingData[i] <= 0;
        state <= S_AWAIT_HEADER;
        isNewPacket <= 1;
        incomingDataCounter <= 0;
    end
    else begin
        if (TVALID && TREADY) begin
            // TLAST coming at the wrong time
            if (TLAST &&
                    !(state == S_AWAIT_LAST ||
                        (state == S_AWAIT_DATA &&
                        incomingDataCounter == NUM_DATA_WORDS-1))) begin
                statusCode <= ST_BAD_SIZE;
                statusToggle <= !statusToggle;
                isNewPacket <= 1;
                state <= S_AWAIT_HEADER;
            end
            else begin
                case (state)
                S_AWAIT_HEADER: begin
                    if (isNewPacket) begin
                        isNewPacket <= 0;
                    end
                    if (headerMagic == expectedHeaderMagic) begin
                        packetIndex <= headerIndex;
                        state <= S_AWAIT_DATA;
                    end
                    else begin
                        statusCode <= ST_BAD_HEADER;
                        statusToggle <= !statusToggle;
                        isNewPacket <= 1;
                        state <= S_AWAIT_LAST;
                    end
                end

                S_AWAIT_DATA: begin
                    incomingData[incomingDataCounter] <= TDATA;

                    if (TLAST) begin
                        isNewPacket <= 1;
                        statusCode <= ST_SUCCESS;
                        statusToggle <= !statusToggle;
                        packetToggle <= !packetToggle;
                    end

                    if (incomingDataCounter == NUM_DATA_WORDS-1) begin
                        incomingDataCounter <= 0;
                        state <= S_AWAIT_HEADER;
                    end
                    else begin
                        incomingDataCounter <= incomingDataCounter+1;
                    end
                end

                S_AWAIT_LAST: begin
                    if (TLAST) begin
                        state <= S_AWAIT_HEADER;
                    end
                end
                default: ;
                endcase
            end
        end
    end
end

genvar j;
generate
for (j = 0; j < NUM_DATA_WORDS; j = j+1) begin : data_flatten
    assign packetData[32*(j+1)-1 : 32*j] = incomingData[j];
end
endgenerate

endmodule
