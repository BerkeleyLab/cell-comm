`timescale 1ns / 100ps

module rr_arb_tb;

reg module_done = 0;
reg module_ready = 0;
reg fail = 0;
integer errors = 0;
integer idx = 0;
initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("rr_arb.vcd");
        $dumpvars(0, rr_arb_tb);
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

reg   [NREQ-1:0] req_bus = 0;
wire  [NREQ-1:0] grant_bus;
rr_arb #(
    .NREQ(NREQ)
)
  DUT(
    .clk(clk),
    .req_bus(req_bus),
    .grant_bus(grant_bus)
);

// stimulus
initial begin
    @(posedge clk);
    module_ready = 1;

    @(posedge clk);
    req_bus = 4'b0000;
    repeat (16)
        @(posedge clk);

    @(posedge clk);
    req_bus = 4'b0101;
    repeat (16)
        @(posedge clk);

    @(posedge clk);
    req_bus = 4'b1111;
    repeat (16)
        @(posedge clk);

    repeat (10)
        @(posedge clk);

    @(posedge clk);
    module_done = 1;
    @(posedge clk);
end

endmodule
