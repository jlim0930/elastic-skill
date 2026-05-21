---
name: ech-performance-capacity
description: Diagnoses ECH performance and capacity issues including high memory pressure, out-of-memory errors, oversharding, data retention causing storage and memory pressure, slow search or indexing due to undersizing, hot nodes and uneven workload distribution, capacity planning for hosted deployments, and AutoOps recommendation interpretation.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECH — Performance & Capacity Sub-Agent

Scope: High memory pressure, OOM errors, oversharding, data retention causing storage/memory pressure, slow search/indexing from undersizing, hot nodes and uneven workload, capacity planning for hosted deployments, AutoOps recommendation interpretation.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECH out of memory"`, `"Elastic Cloud high heap pressure"`, `"ECH oversharding"`, `"Elastic Cloud slow search indexing"`, `"ECH capacity planning"`, `"AutoOps recommendation interpretation"`, `"ECH hot node uneven workload"`.

## Diagnostic Steps

### 1. Memory Pressure — JVM Heap Check
```bash
# Heap usage across all nodes
GET _cat/nodes?v&h=name,heap.percent,heap.current,heap.max,ram.percent,node.role&s=heap.percent:desc

# JVM GC statistics
GET _nodes/stats/jvm | jq '.nodes | to_entries | map({node:.key, heap_pct: (.value.jvm.mem.heap_used_percent), gc_old_ms: (.value.jvm.gc.collectors.old.collection_time_in_millis), gc_young_ms: (.value.jvm.gc.collectors.young.collection_time_in_millis)}) | sort_by(.heap_pct) | reverse | .[0:5]'
```

Thresholds:
| Heap % | Severity | Action |
|---|---|---|
| < 75% | Normal | Monitor |
| 75–85% | High pressure | Investigate workload; consider resize |
| 85–95% | Circuit breakers may trip | Urgent: optimize queries, resize |
| > 95% | OOM imminent | Immediate: reduce load, resize, or force GC |

### 2. OOM Analysis
In ECH, OOM events appear as:
- Instance shows `Restarting` → `Unhealthy` → `Restarting` in the console activity feed
- Deployment logs contain: `OutOfMemoryError`, `java.lang.OutOfMemoryError`, or `Killed`

```bash
# Check circuit breaker trips
GET _nodes/stats/breaker | jq '.nodes | to_entries | map({node:.key, breakers:.value.breakers | to_entries | map(select(.value.tripped > 0)) | map({name:.key, tripped:.value.tripped, limit:.value.limit_size_in_bytes})}) | .[]'

# Check field data cache (common OOM source)
GET _cat/fielddata?v&s=size:desc | head -10

# Check for concurrent search load
GET _nodes/stats/thread_pool | jq '.nodes | to_entries | map({node:.key, search_queue:.value.thread_pool.search.queue, search_rejected:.value.thread_pool.search.rejected}) | sort_by(.search_queue) | reverse | .[0:3]'
```

Common OOM causes:
- Large aggregations or sorts on high-cardinality fields loading data into heap
- Field data cache filling heap (use keyword + doc_values for aggregation fields instead of text)
- Too many concurrent searches — the search heap uses request + field data + segment data
- JVM heap too small for the number of shards × fields

### 3. Oversharding
Oversharding = too many small shards relative to heap, causing excessive memory pressure per shard.

Rule of thumb:
- Target 20-50 GB per shard (not smaller than 1 GB, not larger than 65 GB)
- No more than 20 shards per GB of JVM heap (e.g., 8 GB heap → max 160 shards total per node)

```bash
# Shard count vs. heap ratio
GET _cluster/stats | jq '{total_shards: .indices.shards.total, heap_gb: (.nodes.jvm.mem.heap_max_in_bytes / 1073741824 | round), shards_per_gb: (.indices.shards.total / (.nodes.jvm.mem.heap_max_in_bytes / 1073741824) | round)}'

# Find small shards (< 1 GB)
GET _cat/shards?v&h=index,shard,prirep,store&s=store:asc | head -30

# Find overshareded indices (many small shards on same index)
GET _cat/indices?v&h=index,pri,docs.count,store.size&s=store.size:asc | head -20
```

Fix oversharding:
- For ILM rollover: set `max_primary_shard_size: "40gb"` in the rollover condition
- For old indices: force-merge and shrink or use `_reindex` to combine

### 4. Data Retention Causing Storage / Memory Pressure
```bash
# Disk usage per node
GET _cat/allocation?v&h=node,disk.used,disk.avail,disk.total,disk.percent&s=disk.percent:desc

# Largest indices (by storage)
GET _cat/indices?v&h=index,docs.count,store.size&s=store.size:desc | head -20

# Check ILM status — are indices moving to warm/cold/frozen?
GET _all/_ilm/explain?only_errors=true | jq '.indices | to_entries | map({index:.key, phase:.value.phase, step:.value.step, error:.value.step_info.reason}) | .[:10]'
```

If disk is approaching watermark (> 85%):
1. Delete or snapshot-then-delete old indices
2. Resize storage in ECH console (plan change to increase storage)
3. Review ILM policy — data may not be rolling to warm/cold/frozen tiers as expected
4. Enable searchable snapshots for cold/frozen data to reduce disk footprint

ECH disk watermarks:
- `high` watermark: 90% disk used — no new shards allocated
- `flood_stage` watermark: 95% — indices go read-only

### 5. Slow Search or Indexing Due to Undersizing
```bash
# Search thread pool — queue buildup = search pressure
GET _cat/thread_pool/search?v&h=name,active,queue,rejected

# Write thread pool — queue buildup = indexing pressure
GET _cat/thread_pool/write?v&h=name,active,queue,rejected

# Indexing latency
GET _nodes/stats/indices/indexing | jq '.nodes | to_entries | map({node:.key, indexing_time_ms:.value.indices.indexing.index_time_in_millis, indexing_count:.value.indices.indexing.index_total}) | sort_by(.indexing_time_ms) | reverse | .[0:5]'
```

High search queue + high heap = cluster needs more compute (CPU/RAM). Resize in ECH console.
High write queue + rejections = cluster cannot keep up with indexing rate — resize or reduce indexing load.

### 6. Hot Nodes / Uneven Workload Distribution
```bash
# CPU and search activity per node
GET _cat/nodes?v&h=name,cpu,load_1m,search,index,node.role&s=cpu:desc

# Shard distribution (are shards evenly spread?)
GET _cat/shards?v&h=index,shard,prirep,node&s=node | head -40

# Count shards per node
GET _cat/shards?h=node | sort | uniq -c | sort -rn
```

Hot nodes (1-2 nodes with much higher CPU/load than others) indicate:
- Shard imbalance — most primary shards on one or two nodes
- ILM allocation filters routing all traffic to specific nodes
- Rollover indices always placed on same node

Fix imbalance:
```bash
# Force rebalancing
POST _cluster/reroute?retry_failed=true

# Check allocation settings that may pin shards
GET _cluster/settings | jq '.persistent | to_entries | map(select(.key | test("routing")))'
```

### 7. AutoOps Recommendation Interpretation
AutoOps analyzes cluster metrics automatically and surfaces actionable recommendations in the ECH console:
- Available under: Deployments → [Deployment] → AutoOps

**Common AutoOps recommendations and what they mean:**

| AutoOps recommendation | Root cause | Action |
|---|---|---|
| "Increase RAM" / "Heap pressure" | JVM heap consistently > 75% | Resize RAM in ECH console |
| "Too many shards" / "Oversharding" | Shard count / heap ratio too high | Consolidate old indices, fix ILM rollover |
| "Increase storage" | Disk usage > 85% | Resize storage or delete/archive old data |
| "Search thread pool rejections" | Search load exceeds cluster capacity | Resize compute or optimize queries |
| "Slow queries" | Long-running search requests | Review query patterns, add `search_idle_after` |
| "Unassigned shards" | Shards cannot be placed | Check ILM, disk watermarks, allocation settings |

### 8. Capacity Planning for Hosted Deployments
ECH sizing guidelines by workload type:

| Workload | RAM per node | Storage per node | Shard target |
|---|---|---|---|
| Logging (write-heavy) | 4–8 GB | 30× RAM | 20–40 GB per shard |
| APM / metrics (time-series) | 4–8 GB | 20× RAM | 5–20 GB per shard |
| Search (read-heavy) | 8–16 GB | 10× RAM | 10–20 GB per shard |
| Mixed / observability | 8 GB | 15–20× RAM | 10–30 GB per shard |

**ECH-specific sizing notes:**
- In ECH, RAM is the primary lever — more RAM = more heap + more page cache for OS I/O
- Storage tier selection (hot/warm/cold/frozen) dramatically affects cost and performance
- Cold/frozen tier with searchable snapshots can serve infrequent queries at much lower cost than hot

### 9. KCS + Docs Lookup
Execute retrieval protocol with the observed heap %, shard count, index sizes, and the specific performance symptom (OOM, slow search, slow indexing, hot node).

## Token Budget
- `_cat/nodes` with heap/cpu columns gives instant capacity picture.
- `_cat/shards` count vs heap for oversharding diagnosis.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
