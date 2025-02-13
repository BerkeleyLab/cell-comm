
module readoutStream_tb;

localparam  ADDR_WIDTH = 9;
localparam  DATA_WIDTH = 32;
localparam  CLK_HALF_PERIOD = 5;
localparam  CLK_FULL_PERIOD = 2 * CLK_HALF_PERIOD;

reg                   clk = 0, reset = 0;
reg                   readoutActive=0, readoutValid=0;
reg  [DATA_WIDTH-1:0] readoutData=0;
wire                  readoutPresent, packetValid;
wire [ADDR_WIDTH-1:0] readoutAddress, packetIndex;
wire [DATA_WIDTH-1:0] packetData;

////////////////////////////////////// DUT /////////////////////////////////////
readoutStream # (
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) DUT (
    .clk(clk),                           // input
    .readoutActive(readoutActive),       // input
    .readoutValid(readoutValid),         // input
    .readoutPresent(readoutPresent),     // input
    .readoutAddress(readoutAddress),     // output [ADDR_WIDTH-1:0]
    .readoutData(readoutData),           // input  [DATA_WIDTH-1:0]
    .packetIndex(packetIndex),           // output [ADDR_WIDTH-1:0]
    .packetData(packetData),             // output [DATA_WIDTH-1:0]
    .packetValid(packetValid),            // output
    .reset(reset)
);

/////////////////////////////// TESTBENCH RESULT ///////////////////////////////
reg module_done = 0;
reg fail = 0;
integer errors = 0;
initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("readoutStream_tb.vcd");
        $dumpvars(3, readoutStream_tb);
    end
    wait(module_done);
    if (fail || errors > 0) $display("FAIL");
    else $display("PASS");
    $finish(0);
end

///////////////////////////////// DPRAM CONTENT ////////////////////////////////
// Network of 2 cell controllers with 32 BPM each:
// 0x20 - 0x3F => CELL #1 (32 BPM)
// 0x40 - 0x5F => CELL #2 (32 BPM)
always @(posedge clk) case(readoutAddress)
    9'h20: readoutData <= 32'h0820;
    9'h21: readoutData <= 32'h0821;
    9'h22: readoutData <= 32'h0822;
    9'h23: readoutData <= 32'h0823;
    9'h24: readoutData <= 32'h0824;
    9'h25: readoutData <= 32'h0825;
    9'h26: readoutData <= 32'h0826;
    9'h27: readoutData <= 32'h0827;
    9'h28: readoutData <= 32'h0828;
    9'h29: readoutData <= 32'h0829;
    9'h2a: readoutData <= 32'h082a;
    9'h2b: readoutData <= 32'h082b;
    9'h2c: readoutData <= 32'h082c;
    9'h2d: readoutData <= 32'h082d;
    9'h2e: readoutData <= 32'h082e;
    9'h2f: readoutData <= 32'h082f;
    9'h30: readoutData <= 32'h0830;
    9'h31: readoutData <= 32'h0831;
    9'h32: readoutData <= 32'h0832;
    9'h33: readoutData <= 32'h0833;
    9'h34: readoutData <= 32'h0834;
    9'h35: readoutData <= 32'h0835;
    9'h36: readoutData <= 32'h0836;
    9'h37: readoutData <= 32'h0837;
    9'h38: readoutData <= 32'h0838;
    9'h39: readoutData <= 32'h0839;
    9'h3a: readoutData <= 32'h083a;
    9'h3b: readoutData <= 32'h083b;
    9'h3c: readoutData <= 32'h083c;
    9'h3d: readoutData <= 32'h083d;
    9'h3e: readoutData <= 32'h083e;
    9'h3f: readoutData <= 32'h083f;
    9'h40: readoutData <= 32'h0840;
    9'h41: readoutData <= 32'h0841;
    9'h42: readoutData <= 32'h0842;
    9'h43: readoutData <= 32'h0843;
    9'h44: readoutData <= 32'h0844;
    9'h45: readoutData <= 32'h0845;
    9'h46: readoutData <= 32'h0846;
    9'h47: readoutData <= 32'h0847;
    9'h48: readoutData <= 32'h0848;
    9'h49: readoutData <= 32'h0849;
    9'h4a: readoutData <= 32'h084a;
    9'h4b: readoutData <= 32'h084b;
    9'h4c: readoutData <= 32'h084c;
    9'h4d: readoutData <= 32'h084d;
    9'h4e: readoutData <= 32'h084e;
    9'h4f: readoutData <= 32'h084f;
    9'h50: readoutData <= 32'h0850;
    9'h51: readoutData <= 32'h0851;
    9'h52: readoutData <= 32'h0852;
    9'h53: readoutData <= 32'h0853;
    9'h54: readoutData <= 32'h0854;
    9'h55: readoutData <= 32'h0855;
    9'h56: readoutData <= 32'h0856;
    9'h57: readoutData <= 32'h0857;
    9'h58: readoutData <= 32'h0858;
    9'h59: readoutData <= 32'h0859;
    9'h5a: readoutData <= 32'h085a;
    9'h5b: readoutData <= 32'h085b;
    9'h5c: readoutData <= 32'h085c;
    9'h5d: readoutData <= 32'h085d;
    9'h5e: readoutData <= 32'h085e;
    9'h5f: readoutData <= 32'h085f;
	default: readoutData <= 0;
endcase
assign readoutPresent = readoutData == 0 ? 0 : 1;

always @(posedge clk) begin
    if (packetValid) begin
        case(packetIndex)
            9'h20: errors += packetData == 32'h0820 ? 0 : 1;
            9'h21: errors += packetData == 32'h0821 ? 0 : 1;
            9'h22: errors += packetData == 32'h0822 ? 0 : 1;
            9'h23: errors += packetData == 32'h0823 ? 0 : 1;
            9'h24: errors += packetData == 32'h0824 ? 0 : 1;
            9'h25: errors += packetData == 32'h0825 ? 0 : 1;
            9'h26: errors += packetData == 32'h0826 ? 0 : 1;
            9'h27: errors += packetData == 32'h0827 ? 0 : 1;
            9'h28: errors += packetData == 32'h0828 ? 0 : 1;
            9'h29: errors += packetData == 32'h0829 ? 0 : 1;
            9'h2a: errors += packetData == 32'h082a ? 0 : 1;
            9'h2b: errors += packetData == 32'h082b ? 0 : 1;
            9'h2c: errors += packetData == 32'h082c ? 0 : 1;
            9'h2d: errors += packetData == 32'h082d ? 0 : 1;
            9'h2e: errors += packetData == 32'h082e ? 0 : 1;
            9'h2f: errors += packetData == 32'h082f ? 0 : 1;
            9'h30: errors += packetData == 32'h0830 ? 0 : 1;
            9'h31: errors += packetData == 32'h0831 ? 0 : 1;
            9'h32: errors += packetData == 32'h0832 ? 0 : 1;
            9'h33: errors += packetData == 32'h0833 ? 0 : 1;
            9'h34: errors += packetData == 32'h0834 ? 0 : 1;
            9'h35: errors += packetData == 32'h0835 ? 0 : 1;
            9'h36: errors += packetData == 32'h0836 ? 0 : 1;
            9'h37: errors += packetData == 32'h0837 ? 0 : 1;
            9'h38: errors += packetData == 32'h0838 ? 0 : 1;
            9'h39: errors += packetData == 32'h0839 ? 0 : 1;
            9'h3a: errors += packetData == 32'h083a ? 0 : 1;
            9'h3b: errors += packetData == 32'h083b ? 0 : 1;
            9'h3c: errors += packetData == 32'h083c ? 0 : 1;
            9'h3d: errors += packetData == 32'h083d ? 0 : 1;
            9'h3e: errors += packetData == 32'h083e ? 0 : 1;
            9'h3f: errors += packetData == 32'h083f ? 0 : 1;
            9'h40: errors += packetData == 32'h0840 ? 0 : 1;
            9'h41: errors += packetData == 32'h0841 ? 0 : 1;
            9'h42: errors += packetData == 32'h0842 ? 0 : 1;
            9'h43: errors += packetData == 32'h0843 ? 0 : 1;
            9'h44: errors += packetData == 32'h0844 ? 0 : 1;
            9'h45: errors += packetData == 32'h0845 ? 0 : 1;
            9'h46: errors += packetData == 32'h0846 ? 0 : 1;
            9'h47: errors += packetData == 32'h0847 ? 0 : 1;
            9'h48: errors += packetData == 32'h0848 ? 0 : 1;
            9'h49: errors += packetData == 32'h0849 ? 0 : 1;
            9'h4a: errors += packetData == 32'h084a ? 0 : 1;
            9'h4b: errors += packetData == 32'h084b ? 0 : 1;
            9'h4c: errors += packetData == 32'h084c ? 0 : 1;
            9'h4d: errors += packetData == 32'h084d ? 0 : 1;
            9'h4e: errors += packetData == 32'h084e ? 0 : 1;
            9'h4f: errors += packetData == 32'h084f ? 0 : 1;
            9'h50: errors += packetData == 32'h0850 ? 0 : 1;
            9'h51: errors += packetData == 32'h0851 ? 0 : 1;
            9'h52: errors += packetData == 32'h0852 ? 0 : 1;
            9'h53: errors += packetData == 32'h0853 ? 0 : 1;
            9'h54: errors += packetData == 32'h0854 ? 0 : 1;
            9'h55: errors += packetData == 32'h0855 ? 0 : 1;
            9'h56: errors += packetData == 32'h0856 ? 0 : 1;
            9'h57: errors += packetData == 32'h0857 ? 0 : 1;
            9'h58: errors += packetData == 32'h0858 ? 0 : 1;
            9'h59: errors += packetData == 32'h0859 ? 0 : 1;
            9'h5a: errors += packetData == 32'h085a ? 0 : 1;
            9'h5b: errors += packetData == 32'h085b ? 0 : 1;
            9'h5c: errors += packetData == 32'h085c ? 0 : 1;
            9'h5d: errors += packetData == 32'h085d ? 0 : 1;
            9'h5e: errors += packetData == 32'h085e ? 0 : 1;
            9'h5f: errors += packetData == 32'h085f ? 0 : 1;
            default: errors += packetData == 32'h0000 ? 0 : 1;
        endcase
    end
end

/////////////////////////////////// STIMULUS ///////////////////////////////////
always #CLK_HALF_PERIOD  clk = ! clk ;
initial begin
    #CLK_HALF_PERIOD;
    // Cell link timeout case
    #(10 * CLK_FULL_PERIOD); readoutActive <= 1;
    #(10 * CLK_FULL_PERIOD); readoutActive <= 0;
    #(80 * CLK_FULL_PERIOD); reset <= 1;
    #(CLK_FULL_PERIOD);      reset <= 0;
    #(10 * CLK_FULL_PERIOD); wait(DUT.state == 0);
    // Cell link successful case
    #(10 * CLK_FULL_PERIOD);
    #(CLK_FULL_PERIOD);      readoutActive <= 1;
    #(10 * CLK_FULL_PERIOD); readoutActive <= 0;
    #(CLK_FULL_PERIOD);      readoutValid <= 1;
    #(10 * CLK_FULL_PERIOD); wait(DUT.state == 0);
    #(10 * CLK_FULL_PERIOD); module_done <= 1;
end

endmodule