`timescale 1ns / 100ps

module rrArbReq_tb;

reg module_done = 0;
reg module_ready = 0;
reg fail = 0;
integer errors = 0;
integer idx = 0;
initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("rrArbReq.vcd");
        $dumpvars(0, rrArbReq_tb);
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

integer cc;
reg clk = 0;
initial begin
    clk = 0;
    for (cc = 0; cc < 1000; cc = cc+1) begin
        clk = 0; #5;
        clk = 1; #5;
    end
end

//////////////////////////////////////////////////////////
// Testbench
//////////////////////////////////////////////////////////

localparam NREQ = 4;

reg   [NREQ-1:0] reqBus = 0;
reg              reqArb = 0;
wire  [NREQ-1:0] grantBus;
rrArbReq #(
    .TIMEOUT_CNT_MAX(16),
    .NREQ(NREQ)
)
  DUT(
    .clk(clk),
    .reqArb(reqArb),
    .reqBus(reqBus),
    .grantBus(grantBus)
);

// stimulus
initial begin
    @(posedge clk);
    module_ready <= 1;

    @(posedge clk);
    reqBus <= 4'b0000;
    repeat (64)
        @(posedge clk);

    @(posedge clk);
    reqBus <= 4'b0101;
    repeat (96)
        @(posedge clk);

    reqArb <= 1'b1;
    @(posedge clk);
    reqArb <= 1'b0;

    repeat(8)
        @(posedge clk);

    reqArb <= 1'b1;
    @(posedge clk);
    reqArb <= 1'b0;

    repeat(8)
        @(posedge clk);

    @(posedge clk);
    reqBus <= 4'b0111;
    repeat (64)
        @(posedge clk);

    @(posedge clk);
    reqBus <= 4'b1110;
    repeat (64)
        @(posedge clk);

    @(posedge clk);
    reqBus <= 4'b0000;
    repeat (64)
        @(posedge clk);

    @(posedge clk);
    reqBus <= 4'b1111;
    repeat (64)
        @(posedge clk);

    repeat (256)
        @(posedge clk);

    @(posedge clk);
    module_done <= 1;
    @(posedge clk);
end

endmodule
