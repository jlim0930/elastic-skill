---
name: es-shard-allocation
description: Diagnoses Elasticsearch shard allocation failures, disk watermark breaches, and rebalancing issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES Shard Allocation Sub-Agent

Scope: allocation failures, disk watermarks, rebalancing, oversharded clusters, shard sizing problems.

## Retrieval Protocol
Follow [../../../shared/retrieval-protocol.md](../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"disk watermark allocation"`, `"shard allocation failed"`, `"flood stage read-only"`.

## Diagnostic Steps

### 1. Allocation Explain
```
GET /_cluster/allocation/explain
```
Key fields: `can_allocate`, `allocate_explanation`, `node_allocation_decisions[*].decider_decisions`.
Common decider blocks:
- `disk_threshold` → node at or above watermark
- `filter` / `awareness` → routing allocation filters
- `max_retry` → allocation attempt limit exceeded (use `POST /_cluster/reroute?retry_failed`)

### 2. Disk Watermarks
```
GET /_cat/nodes?v&h=name,disk.avail,disk.used,disk.total
GET /_cluster/settings?include_defaults&flat_settings&filter_path=*.cluster.routing.allocation.disk*
```
Compare used% against watermarks:
- `low` (default 85%) → no new shards
- `high` (default 90%) → relocation away from node
- `flood_stage` (default 95%) → indices become read-only
If indices are read-only: `PUT /<index>/_settings {"index.blocks.read_only_allow_delete": null}`

### 3. Shard Sizing
```
GET /_cat/indices?v&s=store.size:desc&h=index,pri,rep,store.size,docs.count
```
Use `jq` for JSON; filter to flag:
- Shards <100 MB → oversharded
- Shards >50 GB → recovery risk
Count shards vs. nodes × heap (target ≤20 shards per GB heap per node).

### 4. Allocation Filters
```
GET /_cluster/settings?flat_settings&include_defaults&filter_path=*.routing*
```
Check for `index.routing.allocation.require.*` or `cluster.routing.allocation.exclude.*` blocking placement.

### 5. KCS + Docs Lookup
Execute retrieval protocol now. Query with the specific decider block found (e.g., `"disk threshold decider"`).

## Token Budget
- `jq` filter cluster state to relevant shard entries only.
- `grep` `allocation/explain` output for `"can_allocate": "no"` lines.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../shared/output-format.md](../../../shared/output-format.md).
Reference thresholds from [../../../shared/thresholds.md](../../../shared/thresholds.md).
