---
name: es-ingest-performance
description: Diagnoses Elasticsearch indexing latency, bulk rejections, hot threads, write queue buildup, and ingest pipeline bottlenecks.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES Ingest Performance Sub-Agent

Scope: slow indexing, bulk rejections, write thread pool saturation, hot threads on ingest, ingest pipeline failures, backpressure.

## Retrieval Protocol
Follow [../../../shared/retrieval-protocol.md](../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"bulk rejected write thread pool"`, `"indexing latency slow"`, `"ingest pipeline backpressure"`.

## Diagnostic Steps

### 1. Thread Pool Status
```
GET /_cat/thread_pool/write?v&h=name,active,queue,rejected,completed
GET /_cat/thread_pool?v&s=rejected:desc
```
- `write.rejected` > 0 → bulk rejections happening now.
- `write.queue` > 0 sustained → write backpressure.
Thresholds: queue >100 = Warning; any rejected > 0 = investigate immediately.

### 2. Indexing Stats
```
GET /_stats/indexing?pretty
```
Extract `index_total`, `index_time_in_millis`, `index_failed` per index.
Average latency = `index_time_in_millis / index_total`. >10ms per document = slow indexing.

### 3. Hot Threads
```
GET /_nodes/hot_threads
```
Use `grep` for `index\|bulk\|write` to isolate indexing threads.
CPU 100% on write threads with no GC = CPU-bound ingest (check bulk size, mapping complexity).

### 4. Ingest Pipelines
```
GET /_nodes/stats/ingest?pretty
```
Use `jq` to find pipelines with high `time_in_millis` or elevated `failed` counts:
```
jq '.nodes[].ingest.pipelines | to_entries[] | select(.value.time_in_millis > 1000)'
```
Test specific pipeline with simulate API:
```
POST /_ingest/pipeline/<id>/_simulate
```

### 5. Segment and Merge Pressure
```
GET /_cat/indices?v&h=index,segments.count,merges.current,merges.total_time
```
High segment count (>200 per shard) or active merges on all nodes = merge pressure slowing indexing.

### 6. Bulk Request Tuning Signals
- Too-small bulk batches (<100 docs) → increase to 1,000–5,000 docs per request.
- `refresh_interval: 1s` on write-heavy indices → increase to `30s` or `-1` during bulk load.
- `index.translog.durability: async` → reduce fsync overhead (trade-off: data loss on crash).

### 7. KCS + Docs Lookup
Execute retrieval protocol now. Query with thread pool name and rejection count context.

## Token Budget
- Filter `_stats` to `indexing` only; never load full `_stats` output.
- `grep` hot_threads output for write-related frames only.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../shared/output-format.md](../../../shared/output-format.md).
Reference thresholds from [../../../shared/thresholds.md](../../../shared/thresholds.md).
