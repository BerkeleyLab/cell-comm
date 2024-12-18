include ../../dir_list.mk
# Include bedrock here and not in "dir_list.mk",
# as it will conflict if the repository using
# this repo
include $(CELL_COMM_BEDROCK_DIR)/dir_list.mk
.PHONY: all
all: targets
include $(BUILD_DIR)/top_rules.mk
include rules_simulation.mk
include $(BUILD_DIR)/bottom_rules.mk
