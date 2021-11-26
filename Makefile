# contrib/diskquota/Makefile

MODULE_big = diskquota

EXTENSION = diskquota
DATA = diskquota--1.0.sql diskquota--2.0.sql diskquota--1.0--2.0.sql diskquota--2.0--1.0.sql
SRCDIR = ./
FILES = diskquota.c enforcement.c quotamodel.c gp_activetable.c diskquota_utility.c relation_cache.c
OBJS = diskquota.o enforcement.o quotamodel.o gp_activetable.o diskquota_utility.o relation_cache.o
PG_CPPFLAGS = -I$(libpq_srcdir)
SHLIB_LINK = $(libpq)

REGRESS = dummy
ifeq ("$(INTEGRATION_TEST)","y")
REGRESS_OPTS = --schedule=diskquota_schedule_int --init-file=init_file
else
REGRESS_OPTS = --schedule=diskquota_schedule --init-file=init_file
endif

# FIXME: This check is hacky, since test_fetch_table_stat relies on the
# gp_inject_fault extension, we detect if the extension is built with
# greenplum by checking the output of the command 'pg_config --configure'.
# In the future, if the diskquota is built with GPDB7, or we backport the
# commit below to 6X_STABLE, we don't need this check.
# https://github.com/greenplum-db/gpdb/commit/8b897b12f6cb13753985faacab8e4053bf797a8b
ifneq (,$(findstring '--enable-debug-extensions',$(shell pg_config --configure)))
REGRESS_OPTS += --load-extension=gp_inject_fault
else
REGRESS_OPTS += --exclude-tests=test_fetch_table_stat
endif

PGXS := $(shell pg_config --pgxs)
include $(PGXS)
