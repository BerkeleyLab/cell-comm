##################################################################
# CREATE IP aurora8b10b
##################################################################

set aurora8b10b [create_ip -name aurora_8b10b -vendor xilinx.com -library ip -version 11.1 -module_name aurora8b10b]

set_property -dict {
  CONFIG.C_LANE_WIDTH {4}
  CONFIG.C_INIT_CLK {100.0}
  CONFIG.DRP_FREQ {100.0}
  CONFIG.C_USE_CRC {true}
  CONFIG.SupportLevel {0}
  CONFIG.TransceiverControl {true}
} [get_ips aurora8b10b]

set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $aurora8b10b

##################################################################

