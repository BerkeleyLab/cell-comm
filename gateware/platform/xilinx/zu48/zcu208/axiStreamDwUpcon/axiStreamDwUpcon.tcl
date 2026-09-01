##################################################################
# CREATE IP axiStreamDwUpcon
##################################################################

set axiStreamDwUpcon [create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name axiStreamDwUpcon]

set_property -dict {
  CONFIG.S_TDATA_NUM_BYTES {4}
  CONFIG.M_TDATA_NUM_BYTES {8}
  CONFIG.HAS_TLAST {1}
  CONFIG.HAS_MI_TKEEP {1}
  CONFIG.CLKIF.FREQ_HZ {97656250}
} [get_ips axiStreamDwUpcon]

set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $axiStreamDwUpcon

##################################################################

