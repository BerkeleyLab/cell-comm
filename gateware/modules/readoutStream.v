module readoutStream #(
    parameter ADDR_WIDTH = 9,
    parameter DATA_WIDTH = 32
) (
    input wire                  clk,
    input wire                  readoutActive,
    input wire                  readoutValid,
    input wire                  reset,

    input wire                  readoutPresent,
    output reg [ADDR_WIDTH-1:0] readoutAddress = 0,
    input wire [DATA_WIDTH-1:0] readoutData,

    output reg [ADDR_WIDTH-1:0] packetIndex = 0,
    output reg [DATA_WIDTH-1:0] packetData = 0,
    output reg                  packetValid = 0
);

reg readoutActive_d = 0, readoutValid_d = 0;
reg [ADDR_WIDTH-1:0] readoutAddress_d = 0;

localparam ST_IDLE             = 2'd0,
           ST_READ             = 2'd1;
reg [0:0] state = ST_IDLE;

always @(posedge clk) begin
    readoutActive_d <= readoutActive;
    readoutValid_d <= readoutValid;
    readoutAddress_d <= readoutAddress;
    packetValid <= 0;
    if (reset) state <= ST_IDLE;
    else begin
        case (state)
        ST_IDLE: begin
            // Wait for new data to arrive or acquisition interval to end
            if ((readoutValid && !readoutValid_d)
            || (!readoutActive && readoutActive_d)) begin
                readoutAddress <= 0;
                state <= ST_READ;
            end
        end

        ST_READ: begin
            if (readoutAddress == (1<<ADDR_WIDTH)-1) begin
                readoutAddress <= 0;
                state <= ST_IDLE;
            end else begin
                readoutAddress <= readoutAddress + 1;
            end

            if (readoutPresent) begin
                packetIndex <= readoutAddress_d;
                packetData <= readoutData;
                packetValid <= 1;
            end
        end

        default:
            state <= ST_IDLE;
        endcase
    end
end

endmodule
