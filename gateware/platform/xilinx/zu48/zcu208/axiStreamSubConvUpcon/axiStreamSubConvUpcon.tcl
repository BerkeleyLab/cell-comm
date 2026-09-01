##################################################################
# CREATE IP axiStreamSubConvUpcon
##################################################################

set axiStreamSubConvUpcon [create_ip -name axis_subset_converter -vendor xilinx.com -library ip -version 1.1 -module_name axiStreamSubConvUpcon]

set_property -dict {
  CONFIG.S_TDATA_NUM_BYTES {8}
  CONFIG.M_TDATA_NUM_BYTES {8}
  CONFIG.S_HAS_TKEEP {1}
  CONFIG.S_HAS_TLAST {1}
  CONFIG.M_HAS_TKEEP {1}
  CONFIG.M_HAS_TLAST {1}
  CONFIG.TDATA_REMAP {tdata[31:0],tdata[63:32]}
  CONFIG.TKEEP_REMAP {tkeep[3:0],tkeep[7:4]}
  CONFIG.TLAST_REMAP {tlast[0]}
  CONFIG.CLKIF.FREQ_HZ {97656250}
} [get_ips axiStreamSubConvUpcon]

set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $axiStreamSubConvUpcon

##################################################################

