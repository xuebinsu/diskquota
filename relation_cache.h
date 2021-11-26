#ifndef RELATION_CACHE_H
#define RELATION_CACHE_H

#include "storage/relfilenode.h"
#include "utils/relcache.h"
#include "storage/lock.h"
#include "postgres.h"


typedef struct DiskQuotaRelationCacheEntry
{
	Oid 				relid;
	Oid					primary_table_relid;
	Oid					auxrel_oid[10];
	Oid					auxrel_num;
	Oid					owneroid;
	Oid					namespaceoid;
	RelFileNodeBackend	rnode;
}		DiskQuotaRelationCacheEntry;

typedef struct DiskQuotaRelidCacheEntry
{
	Oid			 		relfilenode;
	Oid					relid;
}		DiskQuotaRelidCacheEntry;

extern HTAB *relation_cache;

extern void init_shm_worker_relation_cache(void);
extern Oid get_relid_by_relfilenode(RelFileNode relfilenode);
extern void remove_cache_entry(Oid relid, Oid relfilenode);
extern Oid get_uncommitted_table_relid(Oid relfilenode);
extern void update_relation_cache(Oid relid);
extern Oid get_primary_table_oid(Oid relid);
extern void remove_committed_relation_from_cache(void);

#define atooid(x)  ((Oid) strtoul((x), NULL, 10))

#endif