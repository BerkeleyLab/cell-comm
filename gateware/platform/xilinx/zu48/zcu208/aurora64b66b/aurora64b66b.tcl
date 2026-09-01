##################################################################
# CREATE IP aurora64b66b
##################################################################

set aurora64b66b [create_ip -name aurora_64b66b -vendor xilinx.com -library ip -version 12.0 -module_name aurora64b66b]

set_property -dict { 
  CONFIG.C_GT_TYPE {GTY}
  CONFIG.C_LINE_RATE {3.125}
  CONFIG.C_REFCLK_FREQUENCY {156.25}
  CONFIG.C_INIT_CLK {39.062}
  CONFIG.C_UCOLUMN_USED {left}
  CONFIG.C_START_QUAD {Quad_X0Y1}
  CONFIG.C_REFCLK_SOURCE {MGTREFCLK1_of_Quad_X0Y1}
  CONFIG.C_REFCLK2_SOURCE {None}
  CONFIG.C_REFCLK3_SOURCE {None}
  CONFIG.C_REFCLK4_SOURCE {None}
  CONFIG.C_REFCLK5_SOURCE {None}
  CONFIG.SINGLEEND_INITCLK {true}
  CONFIG.SINGLEEND_GTREFCLK {false}
  CONFIG.C_GT_CLOCK_1 {GTYQ0}
  CONFIG.crc_mode {true}
  CONFIG.drp_mode {Native}
  CONFIG.SupportLevel {0}
  CONFIG.TransceiverControl {true}
} [get_ips aurora64b66b]

set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $aurora64b66b

##################################################################
