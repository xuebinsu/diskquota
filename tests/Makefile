.PHONY: set_guc_variables
set_guc_variables:
	createdb diskquota || true
	gpconfig -c shared_preload_libraries -v diskquota && \
	gpstop -raf && \
	gpconfig -c diskquota.naptime -v 0 && \
	gpconfig -c diskquota.worker_timeout -v 1 && \
	gpconfig -c max_worker_processes -v 20 && \
	gpstop -raf 

.PHONY: installcheck-regress
installcheck-regress: set_guc_variables
	$(MAKE) -C regress installcheck

## Check whether we are able to run isolation2 tests.
## If the gp_inject_fault extension is not enabled, we emit a warning message for that.
.PHONY: installcheck-isolation2
installcheck-isolation2: set_guc_variables
ifneq (,$(findstring '--enable-debug-extensions',$(shell pg_config --configure)))
	$(MAKE) -C isolation2 installcheck
else
	@echo -e "\033[0;33mThe gp_inject_fault extension is not enabled in the current build of Greenplum, isolation2 tests will not run."
	@echo -e "To enable gp_inject_fault extension, append --enable-debug-extensions option to ./configure\033[0m"
endif
