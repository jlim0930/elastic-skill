---
name: ls-pipeline-throughput-performance
description: Diagnoses Logstash high CPU or memory usage, pipeline lag and event backlog, worker and batch size tuning, filter stage bottlenecks (Grok, Ruby, scripts), output backpressure, uneven throughput across pipelines, and persistent queue performance tradeoffs.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# LS — Pipeline Throughput & Performance

**Purpose**: Identify whether the pipeline bottleneck is at the filter, output, JVM, or worker configuration level, and prescribe the fix.

## Use When
- Pipeline lag growing (input faster than output)
- High CPU on Logstash node
- Throughput lower than expected
- Events/sec dropping without input decline

## Do Not Use When
- Pipeline not starting → logstash/pipeline-startup-config
- Events being lost (not just slow) → logstash/event-loss-delivery
- Output blocked by ES backpressure → logstash/queueing-backpressure (root cause)

## Inputs Needed
- Node Stats API output (events.in vs events.out per pipeline)
- JVM heap % and GC counts
- Slow filter identity (from plugin stats)
- Worker and batch size settings

## Diagnostic Logic

### Performance Signal Chain
- `events_out` << `events_in` → backlog building → find which stage is slow
- High `queue.push_duration_in_millis` → output is slow, queue can't drain
- High `duration_in_millis / events_in` per pipeline → filter stage bottleneck

### JVM Heap Thresholds
- > 75% = Warning — GC pressure building; reduce `pipeline.batch.size`
- > 85% = Critical — GC pauses slowing ALL pipelines simultaneously
- GC pause during filter = entire pipeline stalls

### Worker and Batch Size Tuning
| Setting | Default | Guidance |
|---|---|---|
| `pipeline.workers` | CPU cores | I/O-bound (ES output) → exceed cores; CPU-bound (Grok/Ruby) → keep at core count |
| `pipeline.batch.size` | 125 | High-throughput ES output → 500–2000; CPU-bound filter → keep lower |
| `pipeline.batch.delay` | 50ms | Low-latency → 1–5ms; throughput → higher for better batching |

- Override per pipeline in `pipelines.yml` for workload-specific tuning
- Increasing workers without CPU headroom → context switching overhead, no gain

### Slow Filter Identification
- Use Node Stats API plugin stats — average `duration_ms / events_in` per filter
- > 1ms average per event = slow filter; investigate that plugin specifically
- Common slow filters:
  - **Grok**: complex regex with backtracking → use anchors; `break_on_match: true`
  - **Ruby**: per-event synchronous calls → use translate with pre-built dictionary instead
  - **DNS**: per-event DNS lookup → add `hit_cache_size` and local caching resolver

### Output Backpressure Detection
- High output `duration_ms / events_in` → output is the bottleneck, not filter
- If ES output is slow: check ES write thread pool for rejections (root cause is ES-side)
- Increasing `pipeline.batch.size` sends larger bulk requests → can improve ES throughput

### Persistent Queue I/O Impact
- PQ adds disk I/O overhead vs memory queue
- PQ I/O saturated → move PQ to SSD; reduce `queue.page_capacity` (try 32 MB vs 64 MB default)
- If durability not required → switch to memory queue to eliminate PQ overhead

### Multi-Pipeline Resource Contention
- Multiple pipelines share one JVM heap
- One pipeline consuming all memory → others GC-paused
- Set per-pipeline worker limits in `pipelines.yml`; use separate Logstash instances for isolation

## Shared Skills
→ [performance_triage](../../../../shared/performance_triage.md) — layer-by-layer bottleneck isolation including backpressure chain
→ [log_filtering](../../../../shared/log_filtering.md) — filter for pipeline slow/stall indicators

## KCS Queries
`"logstash pipeline lag backlog events slow"`, `"logstash worker batch size tuning performance"`, `"logstash grok filter bottleneck slow"`, `"persistent queue performance disk I/O logstash"`

## Output
Report: bottleneck layer (filter/output/JVM/worker config), avg ms per event per plugin, recommended tuning changes.
