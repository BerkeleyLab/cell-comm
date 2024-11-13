
module axiDataDownconverter (
    /* Input stage 64-bit */
    input  [63:0]   sAxiStreamTdata,
    input  [7:0]    sAxiStreamTkeep,
    input  [7:0]    sAxiStreamTuser,
    input           sAxiStreamTlast,
    input           sAxiStreamTvalid,
    input           sClk,
    /* Output stage 32-bit */
    output [31:0]   mAxiStreamTdata,
    output [3:0]    mAxiStreamTkeep,
    output [7:0]    mAxiStreamTuser,
    output          mAxiStreamTlast,
    output          mAxiStreamTvalid,
    input           mClk,
    /* Control */
    input           resetN
);

wire [63:0] scToCcTdata;
wire [7:0]  scToCcTkeep;
wire [15:0] scToCcTUser;
wire        scToCcTlast;
wire        scToCcTready;
wire        scToCcTvalid;

wire [63:0] ccToDwcTdata;
wire [7:0]  ccToDwcTkeep;
wire [15:0] ccToDwcTUser;
wire        ccToDwcTlast;
wire        ccToDwcTready;
wire        ccToDwcTvalid;

wire [31:0] dwcToScTdata;
wire [3:0]  dwcToScTkeep;
wire [7:0]  dwcToScTuser;
wire        dwcToScTlast;
wire        dwcToScTready;
wire        dwcToScTvalid;

`ifndef SIMULATE
axiStreamSubConvInDowncon axiStreamSubConvInDownconInst(
    /* Control stage */
    .aresetn(resetN),                                  // input
    /*Input stage */
    .aclk(sClk),                                        // input
    .s_axis_tvalid(sAxiStreamTvalid),                   // input
    .s_axis_tdata(sAxiStreamTdata),                     // input [63:0]
    .s_axis_tkeep(sAxiStreamTkeep),                     // input [7:0]
    .s_axis_tlast(sAxiStreamTlast),                     // input
    .s_axis_tuser({sAxiStreamTuser, sAxiStreamTuser}),  // input [15:0]
    /*Output stage */
    .m_axis_tvalid(scToCcTvalid),                       // output
    .m_axis_tready(scToCcTready),                       // input
    .m_axis_tdata(scToCcTdata),                         // output [63:0]
    .m_axis_tkeep(scToCcTkeep),                         // output [7:0]
    .m_axis_tlast(scToCcTlast),                         // output
    .m_axis_tuser(scToCcTUser),                         // output [15:0]
    .transfer_dropped());                               // output

axiStreamClkConvDowncon axiStreamClkConvDownconInst(
    /* Control stage */
    .s_axis_aresetn(resetN),       // input
    .m_axis_aresetn(resetN),       // input
    /*Input stage */
    .s_axis_aclk(sClk),             // input
    .s_axis_tvalid(scToCcTvalid),   // input
    .s_axis_tready(scToCcTready),   // output
    .s_axis_tdata(scToCcTdata),     // input [63:0]
    .s_axis_tkeep(scToCcTkeep),     // input [7:0]
    .s_axis_tlast(scToCcTlast),     // input
    .s_axis_tuser(scToCcTUser),     // input [15:0]
    /*Output stage */
    .m_axis_aclk(mClk),             // input
    .m_axis_tvalid(ccToDwcTvalid),  // output
    .m_axis_tready(ccToDwcTready),  // input
    .m_axis_tdata(ccToDwcTdata),    // output [63:0]
    .m_axis_tkeep(ccToDwcTkeep),    // output [7:0]
    .m_axis_tlast(ccToDwcTlast),    // output
    .m_axis_tuser(ccToDwcTUser));   // output [15:0]

axiStreamDwDowncon axiStreamDwDownconInst(
    /* Control stage */
    .aresetn(resetN),              // input
    /*Input stage */
    .aclk(mClk),                    // input
    .s_axis_tvalid(ccToDwcTvalid),  // input
    .s_axis_tready(ccToDwcTready),  // output
    .s_axis_tdata(ccToDwcTdata),    // input [63:0]
    .s_axis_tkeep(ccToDwcTkeep),    // input [7:0]
    .s_axis_tlast(ccToDwcTlast),    // input
    .s_axis_tuser(ccToDwcTUser),    // input [15:0]
    /*Output stage */
    .m_axis_tvalid(dwcToScTvalid),  // output
    .m_axis_tready(dwcToScTready),  // input
    .m_axis_tdata(dwcToScTdata),    // output [31:0]
    .m_axis_tkeep(dwcToScTkeep),    // output [3:0]
    .m_axis_tlast(dwcToScTlast),    // output
    .m_axis_tuser(dwcToScTuser));   // output [7:0]

axiStreamSubConvOutDowncon axiStreamSubConvOutDownconInst(
    /* Control stage */
    .aresetn(resetN),  // input
    /*Input stage */
    .aclk(mClk),  // input
    .s_axis_tvalid(dwcToScTvalid),  // input
    .s_axis_tready(dwcToScTready),  // output
    .s_axis_tdata(dwcToScTdata),  // input [31:0]
    .s_axis_tkeep(dwcToScTkeep),  // input [3:0]
    .s_axis_tlast(dwcToScTlast),  // input
    .s_axis_tuser(dwcToScTuser),  // input [7:0]
    /*Output stage */
    .m_axis_tvalid(mAxiStreamTvalid),  // output
    .m_axis_tdata(mAxiStreamTdata),  // output [31:0]
    .m_axis_tkeep(mAxiStreamTkeep),  // output [3:0]
    .m_axis_tlast(mAxiStreamTlast),  // output
    .m_axis_tuser(mAxiStreamTuser)); // output [7:0]

`endif // SIMULATE

endmodule
