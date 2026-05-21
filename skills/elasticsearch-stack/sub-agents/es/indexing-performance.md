---
name: es-indexing-performance
description: Diagnoses Elasticsearch slow indexing throughput, bulk rejections and 429 responses, refresh and merge pressure, translog pressure, hot spotting on specific shards or nodes, mapping explosion affecting indexing speed, and ingest-to-index latency spikes.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — Indexing Performance

**Purpose**: Identify why indexing is slow, bulk requests are being rejected, or ingest latency has spiked.

## Use When
- Bulk requests returning 429
- Write throughput has dropped significantly
- Ingest latency spikes without obvious cause
- Single node receiving all write traffic (hot shard)

## Do Not Use When
- Search is slow without indexing complaints → es/search-performance
- Ingest pipeline processor is failing → es/ingest-pipeline

## Inputs Needed
- Write threadpool queue and rejected counts
- Average indexing latency per index
- Active merges and segment count
- Recent changes (new index, increased ingest rate, schema change)

## Diagnostic Logic

### Write Threadpool First
- `write.rejected` > 0 → bulk requests dropped; reduce ingest rate or add nodes
- `write.queue` > 100 sustained → backpressure; ES can't keep up
- Thread pool size is small by default (min of CPU count, 2); scales with CPUs

Check `ingest` thread pool too if ingest pipelines are in use.

### Indexing Latency
- Average > 10 ms/doc = slow; investigate merge, translog, or mapping
- `index_failed` > 0 = documents failing; check mapping or pipeline errors

### Merge Pressure
- Segment count > 200/shard = active merge storm
- Active merges on multiple nodes simultaneously = I/O saturation
- Signal: constant high I/O during otherwise normal operation
- Relief: increase merge throttle during bulk load; restore after

### Translog Pressure
- Large translog (>512 MB uncommitted) = high recovery risk + write amplification
- During bulk load: set `sync_interval: 30s` and `durability: async`
- Warning: `async` mode risks last-interval data on crash — only for reproducible data

### Refresh Pressure
- Frequent refreshes create many small segments → merge pressure → slow indexing
- During bulk load: disable auto-refresh (`refresh_interval: "-1"`)
- Re-enable to `"1s"` after load completes

### Hot Shard
- One node has disproportionately high indexing stats vs others
- Cause: custom routing key with low cardinality; all writes hash to same shard
- Fix: use random routing suffix or let ES handle routing (default)

### Ingest Latency Spikes
Spike causes (correlate with timing in logs):
- GC pause on coordinating or data node at spike time
- Ingest pipeline bottleneck (script or GeoIP processor slow)
- Network jitter between coordinator and data nodes
- Disk I/O spike from concurrent snapshot or merge

### Mapping Explosion
- > 1,000 fields = Lucene overhead causing slow indexing
- Signal: indexing slows progressively as new field names arrive
- Fix: disable dynamic mapping; use `dynamic: "false"` or `"strict"`

## Shared Skills
→ [performance_triage](../../../../shared/performance_triage.md) — layer bottleneck isolation
→ [log_filtering](../../../../shared/log_filtering.md) — filter for `rejected`, `GC pause`, `merge`

## KCS Queries
`"bulk rejected write thread pool 429"`, `"indexing latency slow merge pressure"`, `"translog flush pressure elasticsearch"`, `"hot shard ingest throughput"`

## Output
Report: threadpool state, latency trend, root cause (merge/translog/hot shard/mapping), recommended fix.
