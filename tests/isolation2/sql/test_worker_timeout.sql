SELECT gp_inject_fault_infinite('diskquota_worker_main', 'suspend', dbid)
  FROM gp_segment_configuration WHERE role='p' AND content=-1;

1&: SELECT diskquota.wait_for_worker_new_epoch();

SELECT pg_sleep(120);

SELECT pg_cancel_backend(pid) FROM pg_stat_activity
WHERE query = 'SELECT diskquota.wait_for_worker_new_epoch();';

1<:

2<: SELECT gp_inject_fault_infinite('diskquota_worker_main', 'resume', dbid)
  FROM gp_segment_configuration WHERE role='p' AND content=-1;