# clean generate IP cores files, but the source ones (.xci or .bd)
clean::
	$(foreach ipcore, $(cell_comm_IP_CORES), find $(cell_comm_zcu208_platform_DIR)$(ipcore) -mindepth 1 -not \( -name \*$(ipcore).xci -o -name \*$(ipcore).bd \) -delete ;)
