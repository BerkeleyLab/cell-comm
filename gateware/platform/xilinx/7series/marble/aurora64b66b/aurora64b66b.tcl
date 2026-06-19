##################################################################
# CREATE IP aurora64b66b
##################################################################

set aurora64b66b [create_ip -name aurora_64b66b -vendor xilinx.com -library ip -version 12.0 -module_name aurora64b66b]

set_property -dict {
  CONFIG.C_REFCLK_FREQUENCY {125.000}
  CONFIG.C_INIT_CLK {100.0}
  CONFIG.SINGLEEND_INITCLK {false}
  CONFIG.SINGLEEND_GTREFCLK {false}
  CONFIG.crc_mode {true}
  CONFIG.drp_mode {Native}
  CONFIG.SupportLevel {0}
  CONFIG.TransceiverControl {true}
} [get_ips aurora64b66b]

set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $aurora64b66b

##################################################################

