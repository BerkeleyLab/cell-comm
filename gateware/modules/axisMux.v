// Simple AXIS mux, mostly for simulation
// since we have big combinatorial paths
//
// * with backpressure handshake (valid/ready)
// * arbitrate only on tlast
// * configurable number of sources
// * FIFO-based design
module axisMux #(
    parameter FIFO_DEPTH    = 8,
    parameter DATA_WIDTH    = 32,
    parameter USER_WIDTH    = 8,
    parameter NUM_SOURCES   = 2
    ) (
    input  wire                                      clk,
    input  wire                                      rst,

    input  wire         [NUM_SOURCES-1:0]            s_valid,
    output wire         [NUM_SOURCES-1:0]            s_ready,
    input  wire         [NUM_SOURCES-1:0]            s_last,
    input  wire         [USER_WIDTH*NUM_SOURCES-1:0] s_user,
    input  wire         [DATA_WIDTH*NUM_SOURCES-1:0] s_data,

    output wire                                      m_valid,
    input  wire                                      m_ready,
    output wire                                      m_last,
    output wire                     [USER_WIDTH-1:0] m_user,
    output wire                     [DATA_WIDTH-1:0] m_data
);

generate
if (NUM_SOURCES > 8) begin
    NUM_SOURCES_bigger_than_8_not_supported();
end
endgenerate

localparam FIFO_AW = $clog2(FIFO_DEPTH+1);
localparam FIFO_DW = DATA_WIDTH+USER_WIDTH+1; // data + user + last bit
localparam FIFO_MAX = 2**FIFO_AW-1;

wire [FIFO_DW-1:0] fifoIn [0:NUM_SOURCES-1];
wire fifoWe [0:NUM_SOURCES-1];
wire [FIFO_DW-1:0] fifoOut [0:NUM_SOURCES-1];
wire fifoRe [0:NUM_SOURCES-1];
reg  fifoForceRe [0:NUM_SOURCES-1];
wire fifoFull [0:NUM_SOURCES-1];
wire fifoEmpty [0:NUM_SOURCES-1];
wire fifoValid [0:NUM_SOURCES-1];
wire fifoAlmostFull [0:NUM_SOURCES-1];
wire signed [FIFO_AW:0] fifoCount [0:NUM_SOURCES-1];

genvar i;
generate
for (i = 0; i < NUM_SOURCES; i = i + 1) begin: fifo_gen

assign fifoIn[i] = {s_last[i],
    s_user[(i+1)*USER_WIDTH-1:i*USER_WIDTH],
    s_data[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH]};
assign fifoWe[i] = s_valid[i] && s_ready[i];

genericFifo #(
    .aw(FIFO_AW),
    .dw(FIFO_DW),
    .fwft(1))
fifo (
    .clk(clk),

    .din(fifoIn[i]),
    .we(fifoWe[i]),

    .dout(fifoOut[i]),
    .re(fifoRe[i]),

    .full(fifoFull[i]),
    .empty(fifoEmpty[i]),

    .count(fifoCount[i])
);

assign fifoValid[i] = !(fifoEmpty[i] || fifoForceRe[i]);
assign fifoAlmostFull[i] = (fifoCount[i] >= FIFO_MAX-2);
assign fifoRe[i] = (fifoValid[i] && grantBus[i] && m_ready) || fifoForceRe[i];

assign s_ready[i] = !fifoAlmostFull[i];

// Reset logic for each FIFO
always @(posedge clk) begin
    if (rst) begin
        fifoForceRe[i] <= 1;
    end else begin
        if (fifoEmpty[i]) begin
            fifoForceRe[i] <= 0;
        end
    end
end

end
endgenerate

// Round-robin scheme for serving sources

wire [NUM_SOURCES-1:0] reqBus;
wire [NUM_SOURCES-1:0] grantBus;

generate
for (i = 0; i < NUM_SOURCES; i = i + 1) begin: grant_gen

assign reqBus[i] = fifoValid[i];

end
endgenerate

wire reqArb;
rrArbReq #(
    .TIMEOUT_CNT_MAX(128),
    .NREQ(NUM_SOURCES)
) rrArbitrer(
    .clk(clk),
    .reqArb(reqArb),
    .reqBus(reqBus),
    .grantBus(grantBus)
);

assign reqArb = m_valid && m_ready && m_last;

localparam NUM_SOURCES_LOG2 = $clog2(NUM_SOURCES+1);

wire [NUM_SOURCES_LOG2-1:0] grantBusBinary;
onehot2binary #(
    .WIDTH(NUM_SOURCES)
) onehot2binary (
    .onehot(grantBus),
    .binary(grantBusBinary)
);

// Output
wire fifoValidGranted = fifoValid[grantBusBinary];
wire [FIFO_DW-1:0] fifoDataGranted = fifoOut[grantBusBinary];

assign m_valid = fifoValidGranted;
assign m_data = fifoDataGranted[DATA_WIDTH-1:0];
assign m_user = fifoDataGranted[DATA_WIDTH+USER_WIDTH-1:DATA_WIDTH];
assign m_last = fifoDataGranted[DATA_WIDTH+USER_WIDTH];

endmodule
