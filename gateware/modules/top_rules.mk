__cell_comm_SRCS = \
	pulseSync.v \
	genericFifo.v \
	genericFifo_2c.v \
	axisMux.v \
	fofbReadLink.v \
	fofbReadLinks.v \
	forwardCellLink.v \
	forwardData.v \
	readBPMlink.v \
	readBPMlinks.v \
	auroraLink.v \
	auroraMGT.v \
	auroraMMCM.v \
	axiDataUpconverter.v \
	axiDataDownconverter.v

cell_comm_SRCS = $(addprefix $(CELL_COMM_MODULES_DIR), $(__cell_comm_SRCS))

vpath %.v $(CELL_COMM_MODULES_DIR)

VFLAGS_DEP += $(addprefix -y, $(CELL_COMM_MODULES_DIR))
VFLAGS_DEP += $(addprefix -I, $(CELL_COMM_MODULES_DIR))

# Ignore RTL version of the fmpsReadLinksMux, use the .xci IP
UNISIM_CRAP += -e 'fmpsReadLinksMux|fofbReadLinksMux'
