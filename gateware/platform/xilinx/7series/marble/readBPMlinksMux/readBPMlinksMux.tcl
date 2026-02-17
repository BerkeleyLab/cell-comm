##################################################################
# CREATE IP readBPMlinksMux
##################################################################

set readBPMlinksMux [create_ip -name axis_interconnect -vendor xilinx.com -library ip -version 1.1 -module_name readBPMlinksMux]

set_property -dict {
  CONFIG.C_NUM_SI_SLOTS {2}
  CONFIG.SWITCH_TDATA_NUM_BYTES {14}
  CONFIG.HAS_TSTRB {false}
  CONFIG.HAS_TKEEP {false}
  CONFIG.HAS_TLAST {false}
  CONFIG.HAS_TID {false}
  CONFIG.HAS_TDEST {false}
  CONFIG.SWITCH_PACKET_MODE {false}
  CONFIG.C_SWITCH_MAX_XFERS_PER_ARB {1}
  CONFIG.C_SWITCH_NUM_CYCLES_TIMEOUT {2000}
  CONFIG.M00_AXIS_TDATA_NUM_BYTES {14}
  CONFIG.S00_AXIS_TDATA_NUM_BYTES {14}
  CONFIG.S00_AXIS_FIFO_MODE {1_(Normal)}
  CONFIG.C_S00_AXIS_FIFO_DEPTH {16}
  CONFIG.S01_AXIS_TDATA_NUM_BYTES {14}
  CONFIG.S01_AXIS_FIFO_MODE {1_(Normal)}
  CONFIG.C_S01_AXIS_FIFO_DEPTH {16}
  CONFIG.M00_S01_CONNECTIVITY {true}
} [get_ips readBPMlinksMux]

set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $readBPMlinksMux

##################################################################

