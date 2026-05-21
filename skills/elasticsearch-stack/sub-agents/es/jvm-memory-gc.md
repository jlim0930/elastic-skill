---
name: es-jvm-memory-gc
description: Diagnoses Elasticsearch high heap usage, frequent or long GC pauses, circuit breaker exceptions, OOM events, fielddata memory pressure, and compressed OOPs boundary issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — JVM / Memory / GC

**Purpose**: Identify why heap is high, GC is pausing, or circuit breakers are tripping, and prescribe remediation.

## Use When
- Circuit breaker exception (`CircuitBreakingException`)
- GC pauses causing search/indexing timeouts
- Heap % consistently above 75%
- OOM errors in logs

## Do Not Use When
- Thread pool rejections without heap pressure → es/cpu-threadpool-os
- Disk full without memory involvement → es/disk-storage-watermark

## Inputs Needed
- Heap % per node
- GC pause durations (old gen)
- Which circuit breaker tripped
- `Xmx` setting from jvm.options

## Diagnostic Logic

### Heap Thresholds
- > 85% = Critical — active CB trip and GC pressure risk
- > 75% = Warning — investigate trend
- Old GC collection time growing faster than elapsed time = GC pressure building

### Circuit Breaker — Which One?
| Breaker | Cause | Fix |
|---|---|---|
| `parent` | Overall budget exceeded | Reduce concurrent ops; add heap or nodes |
| `request` | Large agg or search | Simplify query; use `composite` agg with pagination |
| `fielddata` | Text fields aggregated/sorted | Add `.keyword` sub-field; cap fielddata cache |
| `in_flight_requests` | Large concurrent request bodies | Reduce request payload size |
| `accounting` | Too many retained objects | Reduce shard count; forcemerge old indices |

### GC Pressure
- Pauses > 500 ms = Warning; > 2s = Critical (node may be evicted)
- Full GC (stop-the-world) = cluster believes node is dead
- `to-space exhausted` / `Evacuation Failure` = G1GC under extreme heap pressure
- Filter GC log for pauses > 500ms using `log_filtering` skill

### Heap Sizing Rules
- `Xms` must equal `Xmx` (prevent resize pauses)
- Never exceed 31 GB — crossing this disables compressed OOPs, increasing object overhead 30-50%
- Target: 50% of RAM, max 30 GB
- `mlockall` must be true — swap causes unpredictable GC spikes

### Fielddata Pressure
- High fielddata = text fields used in aggregations without `.keyword`
- Fix: add `.keyword` mapping; use `eager_global_ordinals` for frequently-used keyword fields
- Cap: set `indices.fielddata.cache.size: "20%"` to limit fielddata heap usage

### Remediation Path
1. Heap > 85% with circuit breaker → identify which breaker → reduce query complexity or add heap
2. Heap > 85% with Full GC → emergency: reduce shard count, clear fielddata cache, add nodes
3. Heap 75-85% with GC growing → forcemerge old read-only indices; reduce shard count
4. Heap < 75% with CB trips → optimize the specific query/aggregation triggering that breaker

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter GC log for pauses, filter ES log for `circuit_breaking_exception`
→ [performance_triage](../../../../shared/performance_triage.md) — correlate with thread pool and indexing metrics

## KCS Queries
`"circuit breaker tripped heap elasticsearch"`, `"GC overhead elasticsearch pause"`, `"fielddata memory pressure cache"`, `"OutOfMemoryError elasticsearch OOM"`

## Output
Report: heap % per node, GC pause severity, breaker name and cause, immediate and structural fix.
