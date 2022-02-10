-- start_ignore
CREATE EXTENSION diskquota;
SELECT diskquota.wait_for_worker_new_epoch();
SELECT diskquota.init_table_size_table();
-- end_ignore
