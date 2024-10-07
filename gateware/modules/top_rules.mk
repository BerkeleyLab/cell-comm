__cell_comm_SRCS = \
	fofbReadLink.v \
	fofbReadLinks.v \
	forwardCellLink.v \
	forwardData.v \
	readBPMlink.v \
	readBPMlinks.v
cell_comm_SRCS = $(addprefix $(CELL_COMM_MODULES_DIR), $(__cell_comm_SRCS))

vpath %.v $(CELL_COMM_MODULES_DIR)

VFLAGS_DEP += $(addprefix -y, $(CELL_COMM_MODULES_DIR))
VFLAGS_DEP += $(addprefix -I, $(CELL_COMM_MODULES_DIR))
