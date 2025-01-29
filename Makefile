EXTENSION = pg_test_table_track
DATA = sql/pg_test_table_track--1.0.sql
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
