---
name: es-cluster-health
description: Diagnoses Elasticsearch cluster red/yellow status, master instability, node failures, and primary shard unavailability.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES Cluster Health Sub-Agent

Scope: cluster `red`/`yellow`, master not elected, node leaving/joining instability, primary shards unassigned.

## Retrieval Protocol
Follow [../../../shared/retrieval-protocol.md](../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"cluster red unassigned primary"`, `"master not discovered"`, `"node left cluster"`.

## Diagnostic Steps

### 1. Identify Cluster Status
Extract from provided evidence or run:
```
GET /_cluster/health?pretty
GET /_cluster/state/master_node,nodes?pretty
```
- `status: red` → primary shards missing → immediate action required.
- `status: yellow` → replicas missing → reduced durability, reads OK.

### 2. Find Unassigned Shards
```
GET /_cluster/allocation/explain
GET /_cat/shards?v&s=state&h=index,shard,prirep,state,unassigned.reason
```
Extract only UNASSIGNED rows: `grep "UNASSIGNED"` on `_cat/shards` output.
Map `unassigned.reason` to root cause:
- `NODE_LEFT` → node failure or restart
- `ALLOCATION_FAILED` → repeated allocation errors → check node logs
- `INDEX_CREATED` → new index, check `index.number_of_replicas` vs. node count
- `CLUSTER_RECOVERED` → post-restart; check disk watermarks

### 3. Master Stability
```
GET /_cluster/state/master_node?pretty
GET /_cat/nodes?v&h=name,master,role
```
Repeated master changes in logs → split-brain risk or network partition.
Check `discovery.seed_hosts` and `cluster.initial_master_nodes` in `elasticsearch.yml`.

### 4. Node Failures
```
GET /_cat/nodes?v&h=name,heap.percent,cpu,load_1m,node.role
```
- Missing nodes → check OS, process, heap OOM.
- Heap >85% on any node → escalate to memory-pressure sub-agent.

### 5. KCS + Docs Lookup
Execute retrieval protocol now. Query KCS with the identified `unassigned.reason` and cluster status.

## Token Budget
- Use `grep` to extract only UNASSIGNED lines from `_cat/shards`.
- Use `jq` for JSON cluster state; never load full cluster state file.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../shared/output-format.md](../../../shared/output-format.md).
Reference thresholds from [../../../shared/thresholds.md](../../../shared/thresholds.md).
