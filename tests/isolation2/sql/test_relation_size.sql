--
-- 1. Test that when a relation is dropped before diskquota.relation_size()
--    applying stat(2) on the physical file, diskquota.relation_size() consumes
--    the error and returns 0.
--

CREATE TABLE t_dropped(i int);
-- Insert a small amount of data to 't_dropped'.
INSERT INTO t_dropped SELECT generate_series(1, 100);
-- Shows that the size of relfilenode is not zero.
SELECT diskquota.relation_size('t_dropped');

-- Inject 'suspension' to servers.
SELECT gp_inject_fault_infinite('diskquota_before_stat_relfilenode', 'suspend', dbid)
  FROM gp_segment_configuration WHERE role='p';

-- Session 1 will hang before applying stat(2) to the physical file.
1&: SELECT diskquota.relation_size('t_dropped');
-- Drop the table.
DROP TABLE t_dropped;
-- Remove the injected 'suspension'.
SELECT gp_inject_fault_infinite('diskquota_before_stat_relfilenode', 'reset', dbid)
  FROM gp_segment_configuration WHERE role='p';
-- Session 1 will continue and returns 0.
1<:

-- 2. Test whether relation size is correct under concurrent writes for AO tables.
--    Since no row is deleted, diskquota.relation_size() should be equal to 
--    pg_relation_size().

CREATE TABLE t_ao(i int) WITH (appendonly=true);
1: BEGIN;
1: INSERT INTO t_ao SELECT generate_series(1, 10000);
2: BEGIN;
2: INSERT INTO t_ao SELECT generate_series(1, 10000);
1: COMMIT;
2: COMMIT;
SELECT diskquota.relation_size('t_ao');
SELECT pg_relation_size('t_ao');
DROP TABLE t_ao;
