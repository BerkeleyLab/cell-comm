##################################################################
# CREATE IP axiStreamDwDowncon
##################################################################

set axiStreamDwDowncon [create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name axiStreamDwDowncon]

set_property -dict {
  CONFIG.S_TDATA_NUM_BYTES {8}
  CONFIG.M_TDATA_NUM_BYTES {4}
  CONFIG.TUSER_BITS_PER_BYTE {2}
  CONFIG.HAS_TLAST {1}
  CONFIG.HAS_TKEEP {1}
  CONFIG.CLKIF.FREQ_HZ {97656250}
} [get_ips axiStreamDwDowncon]

set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $axiStreamDwDowncon

##################################################################

