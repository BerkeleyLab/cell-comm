
module axiDataUpconverter (
    /* Input stage 32-bit */
    input  [31:0]   sAxiStreamTdata,
    input           sAxiStreamTlast,
    output          sAxiStreamTready,
    input           sAxiStreamTvalid,
    input           sClk,
    /* Output stage 64-bit */
    output [63:0]   mAxiStreamTdata,
    output [7:0]    mAxiStreamTkeep,
    output          mAxiStreamTlast,
    input           mAxiStreamTready,
    output          mAxiStreamTvalid,
    input           mClk,
    /* Control */
    input           resetN
);

wire [31:0] fifoToDwcTdata;
wire        fifoToDwcTlast;
wire        fifoToDwcTready;
wire        fifoToDwcTvalid;

wire [63:0] dwcToScTdata;
wire [7:0]  dwcToScTkeep;
wire        dwcToScTlast;
wire        dwcToScTready;
wire        dwcToScTvalid;

wire [63:0] scToCcTdata;
wire [7:0]  scToCcTkeep;
wire        scToCcTlast;
wire        scToCcTready;
wire        scToCcTvalid;

`ifndef SIMULATE
axisDataFifo32 aaxisDataFifo32Instr (
    /*Output stage */
    .m_axis_tdata(fifoToDwcTdata),
    .m_axis_tlast(fifoToDwcTlast),
    .m_axis_tready(fifoToDwcTready),
    .m_axis_tvalid(fifoToDwcTvalid),
    /* Control stage */
    .s_axis_aclk(sClk),
    .s_axis_aresetn(resetN),
    /*Input stage */
    .s_axis_tdata(sAxiStreamTdata),
    .s_axis_tlast(sAxiStreamTlast),
    .s_axis_tready(sAxiStreamTready),
    .s_axis_tvalid(sAxiStreamTvalid));

axiStreamDwUpcon axiStreamDwUpconInst (
    /* Control stage */
    .aclk(sClk),
    .aresetn(resetN),
    /*Output stage */
    .m_axis_tdata(dwcToScTdata),
    .m_axis_tkeep(dwcToScTkeep),
    .m_axis_tlast(dwcToScTlast),
    .m_axis_tready(dwcToScTready),
    .m_axis_tvalid(dwcToScTvalid),
    /*Input stage */
    .s_axis_tdata(fifoToDwcTdata),
    .s_axis_tlast(fifoToDwcTlast),
    .s_axis_tready(fifoToDwcTready),
    .s_axis_tvalid(fifoToDwcTvalid));

axiStreamSubConvUpcon axiStreamSubConvUpconInst (
    /* Control stage */
    .aclk(sClk),
    .aresetn(resetN),
    /*Output stage */
    .m_axis_tdata(scToCcTdata),
    .m_axis_tkeep(scToCcTkeep),
    .m_axis_tlast(scToCcTlast),
    .m_axis_tready(scToCcTready),
    .m_axis_tvalid(scToCcTvalid),
    /*Input stage */
    .s_axis_tdata(dwcToScTdata),
    .s_axis_tkeep(dwcToScTkeep),
    .s_axis_tlast(dwcToScTlast),
    .s_axis_tready(dwcToScTready),
    .s_axis_tvalid(dwcToScTvalid));

axiStreamClkConvUpcon axiStreamClkConvUpconInstr (
    /*Output stage */
    .m_axis_tdata(mAxiStreamTdata),
    .m_axis_tkeep(mAxiStreamTkeep),
    .m_axis_tlast(mAxiStreamTlast),
    .m_axis_tready(mAxiStreamTready),
    .m_axis_tvalid(mAxiStreamTvalid),
    /* Control stage */
    .s_axis_aclk(sClk),
    .s_axis_aresetn(resetN),
    .m_axis_aclk(mClk),
    .m_axis_aresetn(resetN),
    /*Input stage */
    .s_axis_tdata(scToCcTdata),
    .s_axis_tkeep(scToCcTkeep),
    .s_axis_tlast(scToCcTlast),
    .s_axis_tready(scToCcTready),
    .s_axis_tvalid(scToCcTvalid));

`endif // SIMULATE

endmodule
