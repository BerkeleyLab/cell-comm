##################################################################
# CREATE IP axiStreamClkConvUpcon
##################################################################

set axiStreamClkConvUpcon [create_ip -name axis_clock_converter -vendor xilinx.com -library ip -version 1.1 -module_name axiStreamClkConvUpcon]

set_property -dict {
  CONFIG.TDATA_NUM_BYTES {8}
  CONFIG.HAS_TKEEP {1}
  CONFIG.HAS_TLAST {1}
  CONFIG.S_CLKIF.FREQ_HZ {97656250}
  CONFIG.M_CLKIF.FREQ_HZ {48828125}
} [get_ips axiStreamClkConvUpcon]

set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $axiStreamClkConvUpcon

##################################################################

