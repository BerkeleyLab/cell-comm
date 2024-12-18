// Gather data from outgoing stream into DPRAM
module fmpsReadLink #(
    parameter INDEX_WIDTH = 5,
    parameter dbg = "false"
) (
    // Cell link
                       input  wire        auroraClk,
    (*mark_debug=dbg*) input  wire        FAstrobe,
    (*mark_debug=dbg*) input  wire        allFMPSpresent,
    (*mark_debug=dbg*) input  wire        TVALID,
    (*mark_debug=dbg*) input  wire        TLAST,
    (*mark_debug=dbg*) input  wire [31:0] TDATA,

    // Link statistics
    (*mark_debug=dbg*) output wire                  statusStrobe,
    (*mark_debug=dbg*) output reg [1:0]             statusCode,
    (*mark_debug=dbg*) output reg                   statusFMPSenabled,
                       output reg [INDEX_WIDTH-1:0] statusFMPSindex,

                       output reg [(1<<INDEX_WIDTH)-1:0] fmpsBitmap,
                       output reg        [INDEX_WIDTH:0] fmpsCounter,

    // Readout (system clock domain)
                       input  wire                   sysClk,
    (*mark_debug=dbg*) input  wire [INDEX_WIDTH-1:0] readoutAddress,
    (*mark_debug=dbg*) output wire            [31:0] readoutFMPS);

//
// Dissect header
//
wire                 [15:0] headerMagic       = TDATA[31:16];
wire                        headerFMPSenabled = TDATA[15];
// Keep compatibility with CC protocol that stores the Cell Index
// starting on header bit 10
wire [INDEX_WIDTH-1:0] headerFMPSIndex   = TDATA[10+:INDEX_WIDTH];
reg  [INDEX_WIDTH-1:0] fmpsIndex;

//
// Reception statistics
//
localparam ST_SUCCESS    = 2'd0,
           ST_BAD_HEADER = 2'd1,
           ST_BAD_SIZE   = 2'd2,
           ST_BAD_PACKET = 2'd3;

//
// Reception state machine
//
localparam S_AWAIT_HEADER      = 2'd0,
           S_AWAIT_DATA        = 2'd1,
           S_AWAIT_LAST        = 2'd2;
(*mark_debug=dbg*) reg  [1:0] state = S_AWAIT_HEADER;
(*mark_debug=dbg*) reg [31:0] dataFMPS;
reg statusToggle = 0, statusToggle_d = 0;
assign statusStrobe = (statusToggle != statusToggle_d);
reg writeToggle = 0, writeToggle_d = 0;
wire writeEnable = (writeToggle != writeToggle_d);
reg [(1<<INDEX_WIDTH)-1:0] packetFMPSmap;
(*mark_debug=dbg*) reg isNewPacket = 0;
(*mark_debug=dbg*) reg updateFMPSmapToggle = 0, updateFMPSmapToggle_d = 0;

always @(posedge auroraClk) begin
    statusToggle_d <= statusToggle;
    writeToggle_d <= writeToggle;
    updateFMPSmapToggle_d <= updateFMPSmapToggle;
    if (FAstrobe) begin
        fmpsBitmap <= 0;
        state <= S_AWAIT_HEADER;
        isNewPacket <= 1;
        fmpsCounter <= 0;
    end
    else begin
        if (updateFMPSmapToggle != updateFMPSmapToggle_d)
                                         fmpsBitmap <= fmpsBitmap | packetFMPSmap;
        if (TVALID) begin
            // TLAST coming at the wrong time
            if (TLAST &&
                    !(state == S_AWAIT_DATA || state == S_AWAIT_LAST)) begin
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
                        packetFMPSmap <= 0;
                    end
                    if (headerMagic == 16'hB6CF) begin
                        // Same index for internal bitmap
                        // and status interface
                        fmpsIndex <= headerFMPSIndex;
                        statusFMPSindex <= headerFMPSIndex;
                        statusFMPSenabled <= headerFMPSenabled;
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
                    dataFMPS <= TDATA;
                    // A one in the most significant bit of the final word
                    // (TDATA[31]) indicates an invalid FMPS to cell controller
                    // packet.
                    // A one in the next-to-most significant bit of the final word
                    // (TDATA[30]) indicates an invalid FMPS (CellController) to
                    // FMPS (CellController) packet.
                    if (!TDATA[31]) begin
                        packetFMPSmap[fmpsIndex] <= 1;
                        if (!allFMPSpresent) writeToggle <= !writeToggle;
                    end

                    if (TLAST) begin
                        isNewPacket <= 1;
                        if (TDATA[30]) begin
                            statusCode <= ST_BAD_PACKET;
                        end
                        else begin
                            if (!allFMPSpresent)
                                      updateFMPSmapToggle <= !updateFMPSmapToggle;
                            statusCode <= ST_SUCCESS;
                            fmpsCounter <= fmpsCounter + 1;
                        end
                        statusToggle <= !statusToggle;
                    end
                    state <= S_AWAIT_HEADER;
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

// Readout DPRAM
reg [31:0] dpram [0:(1<<INDEX_WIDTH)-1];
reg [31:0] dpramQ;
assign readoutFMPS = dpramQ[0+:32];
always @(posedge auroraClk) begin
    if (writeEnable) dpram[fmpsIndex] <= dataFMPS;
end
always @(posedge sysClk) begin
    dpramQ <= dpram[readoutAddress];
end

endmodule
