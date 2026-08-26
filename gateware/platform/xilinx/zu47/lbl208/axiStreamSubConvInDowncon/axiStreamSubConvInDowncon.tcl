##################################################################
# CREATE IP axiStreamSubConvInDowncon
##################################################################

set axiStreamSubConvInDowncon [create_ip -name axis_subset_converter -vendor xilinx.com -library ip -version 1.1 -module_name axiStreamSubConvInDowncon]

set_property -dict {
  CONFIG.S_TDATA_NUM_BYTES {8}
  CONFIG.M_TDATA_NUM_BYTES {8}
  CONFIG.S_TUSER_WIDTH {16}
  CONFIG.M_TUSER_WIDTH {16}
  CONFIG.S_HAS_TREADY {1}
  CONFIG.S_HAS_TKEEP {1}
  CONFIG.S_HAS_TLAST {1}
  CONFIG.M_HAS_TKEEP {1}
  CONFIG.M_HAS_TLAST {1}
  CONFIG.TDATA_REMAP {tdata[31:0],tdata[63:32]}
  CONFIG.TUSER_REMAP {tuser[7:0],tuser[15:8]}
  CONFIG.TKEEP_REMAP {tkeep[3:0],tkeep[7:4]}
  CONFIG.TLAST_REMAP {tlast[0]}
  CONFIG.CLKIF.FREQ_HZ {48828125}
} [get_ips axiStreamSubConvInDowncon]

set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $axiStreamSubConvInDowncon

##################################################################

