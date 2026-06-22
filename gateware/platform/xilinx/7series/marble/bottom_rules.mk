# clean generate IP cores files, but the source ones (.xci or .bd)
clean::
	$(foreach ipcore, \
		$(cell_comm_IP_CORES), \
		test -f $(cell_comm_marble_platform_DIR)$(ipcore)/$(ipcore).xci && \
		find $(cell_comm_marble_platform_DIR)$(ipcore) -mindepth 1 -not \( -name \*$(ipcore).xci -o -name \*$(ipcore).bd -o -name \*$(ipcore).coe \) -delete ;)
