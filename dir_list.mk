# $(TOP) as constructed includes a trailing slash (/)
CELL_COMM_TOP := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

CELL_COMM_DIR                  = $(CELL_COMM_TOP)
CELL_COMM_GATEWARE_DIR         = $(CELL_COMM_DIR)gateware/
CELL_COMM_SOFTWARE_DIR         = $(CELL_COMM_DIR)software/

# Gateware
CELL_COMM_MODULES_DIR          = $(CELL_COMM_GATEWARE_DIR)modules/
CELL_COMM_PLATFORM_DIR         = $(CELL_COMM_GATEWARE_DIR)platform/

# Software
CELL_COMM_SRC_DIR              = $(CELL_COMM_SOFTWARE_DIR)src/
