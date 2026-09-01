##################################################################
# CREATE IP fofbReadLinksMux
##################################################################

set fofbReadLinksMux [create_ip -name axis_interconnect -vendor xilinx.com -library ip -version 1.1 -module_name fofbReadLinksMux]

set_property -dict {
  CONFIG.C_NUM_SI_SLOTS {2}
  CONFIG.SWITCH_TDATA_NUM_BYTES {1}
  CONFIG.HAS_TSTRB {false}
  CONFIG.HAS_TKEEP {false}
  CONFIG.HAS_TLAST {false}
  CONFIG.HAS_TID {false}
  CONFIG.HAS_TDEST {false}
  CONFIG.HAS_TUSER {true}
  CONFIG.SWITCH_PACKET_MODE {false}
  CONFIG.C_SWITCH_MAX_XFERS_PER_ARB {1}
  CONFIG.C_SWITCH_NUM_CYCLES_TIMEOUT {0}
  CONFIG.M00_AXIS_TDATA_NUM_BYTES {1}
  CONFIG.C_M00_AXIS_IS_ACLK_ASYNC {1}
  CONFIG.S00_AXIS_TDATA_NUM_BYTES {1}
  CONFIG.C_S00_AXIS_IS_ACLK_ASYNC {0}
  CONFIG.S00_AXIS_FIFO_MODE {1_(Normal)}
  CONFIG.C_S00_AXIS_FIFO_DEPTH {16}
  CONFIG.S01_AXIS_TDATA_NUM_BYTES {1}
  CONFIG.C_S01_AXIS_IS_ACLK_ASYNC {0}
  CONFIG.S01_AXIS_FIFO_MODE {1_(Normal)}
  CONFIG.C_S01_AXIS_FIFO_DEPTH {16}
  CONFIG.M00_S01_CONNECTIVITY {true}
} [get_ips fofbReadLinksMux]

set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $fofbReadLinksMux

##################################################################

