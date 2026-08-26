##################################################################
# CREATE IP axisDataFifo32
##################################################################

set axisDataFifo32 [create_ip -name axis_data_fifo -vendor xilinx.com -library ip -version 2.0 -module_name axisDataFifo32]

set_property -dict {
  CONFIG.TDATA_NUM_BYTES {4}
  CONFIG.FIFO_DEPTH {256}
  CONFIG.HAS_TLAST {1}
  CONFIG.S_CLKIF.FREQ_HZ {97656250}
} [get_ips axisDataFifo32]

set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $axisDataFifo32

##################################################################

