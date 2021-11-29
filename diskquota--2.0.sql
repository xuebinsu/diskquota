/* contrib/diskquota/diskquota--2.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION diskquota" to load this file. \quit

CREATE SCHEMA diskquota;

-- Configuration table
CREATE TABLE diskquota.quota_config (targetOid oid, quotatype int, quotalimitMB int8, segratio float4 DEFAULT -1, PRIMARY KEY(targetOid, quotatype));

CREATE TABLE diskquota.target (
        quotatype int, --REFERENCES disquota.quota_config.quotatype,
        primaryOid oid,
        tablespaceOid oid, --REFERENCES pg_tablespace.oid,
        PRIMARY KEY (primaryOid, tablespaceOid, quotatype)
);

SELECT pg_catalog.pg_extension_config_dump('diskquota.quota_config', '');
SELECT gp_segment_id, pg_catalog.pg_extension_config_dump('diskquota.quota_config', '') from gp_dist_random('gp_id');

CREATE FUNCTION diskquota.set_schema_quota(text, text)
RETURNS void STRICT
AS 'MODULE_PATHNAME'
LANGUAGE C;

CREATE FUNCTION diskquota.set_role_quota(text, text)
RETURNS void STRICT
AS 'MODULE_PATHNAME'
LANGUAGE C;

CREATE OR REPLACE FUNCTION diskquota.set_schema_tablespace_quota(text, text, text)
RETURNS void STRICT
AS 'MODULE_PATHNAME'
LANGUAGE C;

CREATE OR REPLACE FUNCTION diskquota.set_role_tablespace_quota(text, text, text)
RETURNS void STRICT
AS 'MODULE_PATHNAME'
LANGUAGE C;

CREATE OR REPLACE FUNCTION diskquota.set_per_segment_quota(text, float4)
RETURNS void STRICT
AS 'MODULE_PATHNAME'
LANGUAGE C;

CREATE FUNCTION diskquota.update_diskquota_db_list(oid, int4)
RETURNS void STRICT
AS 'MODULE_PATHNAME'
LANGUAGE C;

CREATE TABLE diskquota.table_size (tableid oid, size bigint, segid smallint, PRIMARY KEY(tableid, segid));

CREATE TABLE diskquota.state (state int, PRIMARY KEY(state));

INSERT INTO diskquota.state SELECT (count(relname) = 0)::int  FROM pg_class AS c, pg_namespace AS n WHERE c.oid > 16384 and relnamespace = n.oid and nspname != 'diskquota';

CREATE FUNCTION diskquota.diskquota_start_worker()
RETURNS void STRICT
AS 'MODULE_PATHNAME'
LANGUAGE C;

CREATE FUNCTION diskquota.init_table_size_table()
RETURNS void STRICT
AS 'MODULE_PATHNAME'
LANGUAGE C;

CREATE OR REPLACE FUNCTION diskquota.pause()
RETURNS void STRICT
AS 'MODULE_PATHNAME', 'diskquota_pause'
LANGUAGE C;

CREATE OR REPLACE FUNCTION diskquota.resume()
RETURNS void STRICT
AS 'MODULE_PATHNAME', 'diskquota_resume'
LANGUAGE C;

CREATE VIEW diskquota.show_fast_schema_quota_view AS
select pgns.nspname as schema_name, pgc.relnamespace as schema_oid, qc.quotalimitMB as quota_in_mb, sum(ts.size) as nspsize_in_bytes
from diskquota.table_size as ts,
        pg_class as pgc,
        diskquota.quota_config as qc,
        pg_namespace as pgns
where ts.tableid = pgc.oid and qc.targetoid = pgc.relnamespace and pgns.oid = pgc.relnamespace and qc.quotatype=0 and ts.segid=-1
group by relnamespace, qc.quotalimitMB, pgns.nspname
order by pgns.nspname;

CREATE VIEW diskquota.show_fast_role_quota_view AS
select pgr.rolname as role_name, pgc.relowner as role_oid, qc.quotalimitMB as quota_in_mb, sum(ts.size) as rolsize_in_bytes
from diskquota.table_size as ts,
        pg_class as pgc,
        diskquota.quota_config as qc,
        pg_roles as pgr
WHERE pgc.relowner = qc.targetoid and pgc.relowner = pgr.oid and ts.tableid = pgc.oid and qc.quotatype=1 and ts.segid=-1
GROUP BY pgc.relowner, pgr.rolname, qc.quotalimitMB;

CREATE VIEW diskquota.show_fast_schema_tablespace_quota_view AS
select pgns.nspname as schema_name, pgc.relnamespace as schema_oid, pgsp.spcname as tablespace_name, pgc.reltablespace as tablespace_oid, qc.quotalimitMB as quota_in_mb, sum(ts.size) as nspsize_tablespace_in_bytes
from diskquota.table_size as ts,
        pg_class as pgc,
        diskquota.quota_config as qc,
        pg_namespace as pgns,
	pg_tablespace as pgsp,
	diskquota.target as t
where ts.tableid = pgc.oid and qc.targetoid = pgc.relnamespace and pgns.oid = pgc.relnamespace and pgsp.oid = pgc.reltablespace and qc.quotatype=2 and qc.targetoid=t.primaryoid and t.tablespaceoid=pgc.reltablespace and ts.segid=-1
group by relnamespace, reltablespace, qc.quotalimitMB, pgns.nspname, pgsp.spcname
order by pgns.nspname, pgsp.spcname;

CREATE VIEW diskquota.show_fast_role_tablespace_quota_view AS
select pgr.rolname as role_name, pgc.relowner as role_oid, pgsp.spcname as tablespace_name, pgc.reltablespace as tablespace_oid, qc.quotalimitMB as quota_in_mb, sum(ts.size) as rolsize_tablespace_in_bytes
from diskquota.table_size as ts,
        pg_class as pgc,
        diskquota.quota_config as qc,
        pg_roles as pgr,
	pg_tablespace as pgsp,
        diskquota.target as t
WHERE pgc.relowner = qc.targetoid and pgc.relowner = pgr.oid and ts.tableid = pgc.oid and pgsp.oid = pgc.reltablespace and qc.quotatype=3 and qc.targetoid=t.primaryoid and t.tablespaceoid=pgc.reltablespace and ts.segid=-1
GROUP BY pgc.relowner, reltablespace, pgr.rolname, pgsp.spcname, qc.quotalimitMB;

CREATE VIEW diskquota.show_fast_database_size_view AS
SELECT ((SELECT SUM(pg_relation_size(oid)) FROM pg_class WHERE oid <= 16384)+ (SELECT SUM(size) FROM diskquota.table_size WHERE segid = -1)) AS dbsize;

CREATE TYPE diskquota.diskquota_active_table_type AS ("TABLE_OID" oid,  "TABLE_SIZE" int8, "GP_SEGMENT_ID" smallint);

CREATE OR REPLACE FUNCTION diskquota.diskquota_fetch_table_stat(int4, oid[]) RETURNS setof diskquota.diskquota_active_table_type
AS 'MODULE_PATHNAME', 'diskquota_fetch_table_stat'
LANGUAGE C VOLATILE;

SELECT diskquota.diskquota_start_worker();
DROP FUNCTION diskquota.diskquota_start_worker();

-- TODO: support upgrade/downgrade
CREATE OR REPLACE FUNCTION diskquota.relation_size_local(
        reltablespace oid, 
        relfilenode oid, 
        is_temp boolean)
RETURNS bigint STRICT
AS 'MODULE_PATHNAME', 'relation_size_local'
LANGUAGE C;

CREATE OR REPLACE FUNCTION diskquota.relation_size(
        relation regclass,
        is_temp boolean) 
RETURNS bigint STRICT 
AS $$
SELECT sum(size)::bigint FROM (
        SELECT diskquota.relation_size_local(reltablespace, relfilenode, is_temp) AS size 
        FROM gp_dist_random('pg_class') WHERE oid = relation
        UNION ALL 
        SELECT diskquota.relation_size_local(reltablespace, relfilenode, is_temp) AS size 
        FROM pg_class WHERE oid = relation
) AS t
$$ LANGUAGE SQL;


CREATE TYPE diskquota._relation_cache_detail AS
  (RELID oid, PRIMARY_TABLE_OID oid, AUXREL_NUM int,
   OWNEROID oid, NAMESPACEOID oid, BACKENDID int, SPCNODE oid, DBNODE oid, RELNODE oid, RELSTORAGE "char", AUXREL_OID oid[]);

CREATE OR REPLACE FUNCTION diskquota.show_relation_cache()
RETURNS setof diskquota._relation_cache_detail
AS 'MODULE_PATHNAME', 'show_relation_cache'
LANGUAGE C;

CREATE OR REPLACE FUNCTION diskquota.show_relation_cache_all_seg()
RETURNS setof diskquota._relation_cache_detail 
as $$
WITH relation_cache AS (
    SELECT diskquota.show_relation_cache() AS a
    FROM  gp_dist_random('gp_id')
)
SELECT (a).* FROM relation_cache;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION diskquota.check_relation_cache()
RETURNS boolean
as $$
declare t1 oid[];
declare t2 oid[];
begin
t1 := (select array_agg(distinct((a).relid)) from diskquota.show_relation_cache_all_seg() as a where (a).relid != (a).primary_table_oid);
t2 := (select distinct((a).auxrel_oid) from diskquota.show_relation_cache_all_seg() as a where (a).relid = (a).primary_table_oid);
return t1 = t2;
end;
$$ LANGUAGE plpgsql;