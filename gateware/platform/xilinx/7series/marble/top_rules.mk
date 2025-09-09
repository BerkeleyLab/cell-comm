cell_comm_marble_platform_DIR = $(CELL_COMM_PLATFORM_DIR)xilinx/7series/marble/

cell_comm_IP_CORES = \
	fofbReadLinksMux \
	fmpsReadLinksMux \
	forwardCellLinkMux \
	readBPMlinksMux \
	axisDataFifo32 \
	axiStreamDwUpcon \
	axiStreamSubConvUpcon \
	axiStreamClkConvUpcon \
	axiStreamClkConvDowncon \
	axiStreamDwDowncon \
	axiStreamSubConvInDowncon \
	axiStreamSubConvOutDowncon \
	aurora64b66b \
	ila_td400_s4096_cap

cell_comm_IP_CORES_DIRS = $(addprefix $(cell_comm_marble_platform_DIR), $(cell_comm_IP_CORES))

# For top-level makefile
IP_CORES_XCIS += $(addsuffix .xci, $(cell_comm_IP_CORES))
IP_CORES_DIRS += $(cell_comm_IP_CORES_DIRS)

vpath %.xci $(IP_CORES_DIRS)
