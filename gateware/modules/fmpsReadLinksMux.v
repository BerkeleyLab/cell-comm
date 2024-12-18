// Simulation wrapper for axisMux
module fmpsReadLinksMux (
     input ACLK,
     input ARESETN,
     input S00_AXIS_ACLK,
     input S01_AXIS_ACLK,
     input S00_AXIS_ARESETN,
     input S01_AXIS_ARESETN,
     input S00_AXIS_TVALID,
     input [7:0]S00_AXIS_TDATA,
     input [0:0]S00_AXIS_TUSER,
     input S01_AXIS_TVALID,
     input [7:0]S01_AXIS_TDATA,
     input [0:0]S01_AXIS_TUSER,
     input M00_AXIS_ACLK,
     input M00_AXIS_ARESETN,
     output M00_AXIS_TVALID,
     input M00_AXIS_TREADY,
     output [7:0]M00_AXIS_TDATA,
     output [0:0]M00_AXIS_TUSER,
     input S00_ARB_REQ_SUPPRESS,
     input S01_ARB_REQ_SUPPRESS
);

localparam FIFO_DEPTH    = 8;
localparam DATA_WIDTH    = 8;
localparam USER_WIDTH    = 1;
localparam NUM_SOURCES   = 2;

axisMux #(
    .FIFO_DEPTH(FIFO_DEPTH),
    .DATA_WIDTH(DATA_WIDTH),
    .USER_WIDTH(USER_WIDTH),
    .NUM_SOURCES(NUM_SOURCES)
    ) axisMux (
    .arst(~ARESETN),

    .s_clk({S01_AXIS_ACLK, S00_AXIS_ACLK}),
    .s_tvalid({S01_AXIS_TVALID, S00_AXIS_TVALID}),
    .s_tready(),
    // single data beat per packet
    .s_tlast({S01_AXIS_TVALID, S00_AXIS_TVALID}),
    .s_tuser({S01_AXIS_TUSER, S00_AXIS_TUSER}),
    .s_tdata({S01_AXIS_TDATA, S00_AXIS_TDATA}),

    .m_clk(M00_AXIS_ACLK),
    .m_tvalid(M00_AXIS_TVALID),
    .m_tready(M00_AXIS_TREADY),
    .m_tlast(),
    .m_tuser(M00_AXIS_TUSER),
    .m_tdata(M00_AXIS_TDATA)
);

endmodule
