Cell Controller common modules
==============================

Gateware/Software for Cell Controller communication modules.
This repository is intended to be used as a submodule, so
other projects can reuse the same set of modules.

### How to add this repository as a submodule

1. Use `git submodule add` commmand to add this as a submodule
2. Include dir_list.mk, top_rules.mk and bottom_rules.mk in your Makefile.
Example:

```bash
include $(THIS_REPOSITORY_PATH)/dir_list.mk
include $(THIS_REPOSITORY_PATH)/top_rules.mk

<INSERT YOUR RULES HERE>

include $(THIS_REPOSITORY_PATH)/bottom_rules.mk
```
