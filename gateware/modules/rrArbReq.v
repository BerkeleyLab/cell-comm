/* rr_arb
   Generic round-robin arbiter based on request-grant handshake.
   Can be used as is or can be taken as an example of how the rr_next() function
   can be incorporated into other designs.
*/

module rrArbReq #(
    parameter NREQ = 2,
    parameter TIMEOUT_CNT_MAX = 32
) (
    input             clk,
    // only arbitrate on request
    input             reqArb,
    input  [NREQ-1:0] reqBus,
    output [NREQ-1:0] grantBus
);

function [NREQ-1:0] rr_next;
    input [NREQ-1:0] reqs;
    input [NREQ-1:0] base;
    reg [NREQ*2-1:0] double_req;
    reg [NREQ*2-1:0] double_grant;
begin
    double_req = {reqs, reqs};
    double_grant = ~(double_req - base) & double_req;
    rr_next = double_grant[NREQ*2-1:NREQ] | double_grant[NREQ-1:0];
end
endfunction

localparam TIMEOUT_WIDTH = $clog2(TIMEOUT_CNT_MAX+1);
reg [TIMEOUT_WIDTH:0] timeoutCnt = TIMEOUT_CNT_MAX-2;
wire timeout = timeoutCnt[TIMEOUT_WIDTH];
wire srcServed = |(grantBus & reqBus);

always @(posedge clk) begin
    if (timeout || grantBus_d != grantBus) begin
        timeoutCnt <= TIMEOUT_CNT_MAX-2;
    end
    else if (!timeout && srcServed) begin
        timeoutCnt <= timeoutCnt - 1;
    end
end

// one-hot encoded, next source to be considered
// for being granted the bus
reg [NREQ-1:0] base = 1;
reg reqArb_r = 0;
reg [NREQ-1:0] grantBus_d = 0;

always @(posedge clk) begin
    grantBus_d <= grantBus;

    if (reqArb || timeout ||
        (reqArb_r && ((grantBus_d == grantBus) && |reqBus))) begin
        base <= base << 1 | base[NREQ-1];

        // if grantBus already changed, we know we won't
        // need to shift base by more than 1
        reqArb_r <= 1;
        if (grantBus_d != grantBus) begin
            reqArb_r <= 0;
        end
    end
    else begin
        reqArb_r <= 0;
    end
end

assign grantBus = rr_next(reqBus, base);

endmodule
