cell_comm_zcu208_platform_DIR = $(CELL_COMM_PLATFORM_DIR)xilinx/zu48/zcu208/

cell_comm_IP_CORES = \
	ila_td400_s16384_cap \
	ila_td400_s4096_cap \
	axisDataFifo32 \
	axiStreamDwUpcon \
	axiStreamSubConvUpcon \
	axiStreamClkConvUpcon \
	axiStreamClkConvDowncon \
	axiStreamDwDowncon \
	axiStreamSubConvInDowncon \
	axiStreamSubConvOutDowncon \
	aurora64b66b

cell_comm_IP_CORES_DIRS = $(addprefix $(cell_comm_zcu208_platform_DIR), $(cell_comm_IP_CORES))

# For top-level makefile
IP_CORES_XCIS += $(addsuffix .xci, $(cell_comm_IP_CORES))
IP_CORES_DIRS += $(cell_comm_IP_CORES_DIRS)

vpath %.xci $(IP_CORES_DIRS)
