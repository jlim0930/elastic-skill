---
name: cross-performance-triage
description: Diagnoses end-to-end performance bottlenecks across the Elastic Stack by isolating the failing layer in the data path from Beats/Agent through Logstash to Elasticsearch to Kibana. Covers hot thread analysis, slow log interpretation, thread pool queue buildup, ingest vs search vs UI latency separation, backpressure propagation, and cross-component capacity signals.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Cross-Product — Performance Triage

**Purpose**: Identify which layer in the data path is the bottleneck and prescribe the targeted fix — do not tune all layers simultaneously.

## Use When
- End-to-end latency is high but the failing component is unknown
- Backpressure propagating upstream (Beats blocked, Logstash PQ growing, ES rejecting)
- Mixed ingest + search load causing degradation across multiple components
- Capacity planning: need to identify which layer to scale first

## Do Not Use When
- Bottleneck is already confirmed to one component → use that component's performance sub-agent
- Network connectivity issue (not latency) → cross-product/network

## Inputs Needed
- Symptom: ingest lag / search slowness / Kibana slow / all of the above
- Current write thread pool queue and rejection counts in ES
- Logstash events.in vs events.out ratio
- Kibana response time p50 / p99

## Diagnostic Logic

### Data Path Layers
```
Source → Beats/Agent → [Logstash] → ES Ingest Node → ES Write → ES Search → Kibana
```

### Bottleneck Signal by Layer
| Layer | Signal | Meaning |
|---|---|---|
| Beats | `output busy` or `queue is full` | Logstash or ES is the bottleneck |
| Logstash | PQ growing; `events.out` << `events.in` | ES output is the bottleneck |
| ES write thread pool | `queue > 0` or `rejected > 0` | ES write capacity exceeded |
| ES search thread pool | `queue > 0` or `rejected > 0` | Search capacity exceeded |
| Kibana | `resp_time_avg` > 2000 ms | Slow ES queries behind Kibana |

**Rule**: Fix the bottommost bottleneck first — ES rejecting → fix ES before tuning Logstash or Beats.

### ES Hot Thread Interpretation
| Stack Frame Contains | Bottleneck |
|---|---|
| `IndexingMemoryController`, `InternalEngine` | Indexing pressure |
| `LuceneSearcher`, `QueryPhase`, `BucketCollector` | Heavy search / aggregation |
| `GarbageCollector` | JVM GC — check heap % |
| `PainlessScript`, `ScriptRunner` | Expensive scripts (ingest or query) |
| `SegmentMerger`, `ConcurrentMergeScheduler` | Merge storm — too many segments |
| `Netty`, `TcpTransport` | Network I/O pressure |

### ES Node Performance Thresholds
| Metric | Warning | Critical |
|---|---|---|
| CPU % sustained | > 70% | > 90% |
| Heap % | > 75% | > 85% |
| GC old gen time (% of elapsed) | > 10% | > 30% |
| `load_1m` | > vCPU count | > 2× vCPU count |

### Logstash Performance Signals
- High `push_duration_in_millis` on PQ = disk I/O bottleneck at queue path
- Per-plugin: if any filter averages > 1 ms, it's a candidate for optimization
- Check: `events.in` vs `events.out` per pipeline — gap = output is slow

### Backpressure Propagation Chain
When ES rejects bulk writes, the backpressure propagates upstream:
1. ES bulk rejected → Logstash ES output slows → Logstash PQ fills
2. Logstash PQ full → Logstash Beats input stops reading → Beats output blocks
3. Beats output blocked → Beats harvester pauses → source logs queue on disk

Fix order: ES capacity first, then Logstash sizing, then Beats queue.

### Burst Handling
- ES: increase `thread_pool.write.queue_size` (default 200) to absorb bursts
- Logstash: increase `pipeline.batch.size` (larger batches = higher throughput)
- Beats: increase `queue.mem.events` and `bulk_max_size`
- Only increase queue sizes if the downstream can eventually catch up — queues hide but don't fix capacity issues

### Capacity Planning Signals
| Signal | Action |
|---|---|
| CPU > 70% sustained across all data nodes | Add data nodes |
| Heap > 75% on multiple nodes | Add nodes or increase heap (max 30 GB) |
| Write queue > 50 sustained | Add data nodes or reduce shard count |
| Disk > 75% on any node | Add storage or nodes |
| Shards/node > 20 × heap_GB | Reduce shard count |
| Logstash PQ > 80% of `max_bytes` | Add Logstash workers or increase `max_bytes` |

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for thread pool rejections, slow log entries, backpressure indicators across all components
→ [authentication_checks](../../../../shared/authentication_checks.md) — rule out auth errors masking as slow responses

## KCS Queries
`"elastic stack end-to-end latency bottleneck isolation ingest search"`, `"elasticsearch thread pool write rejected bulk backpressure"`, `"logstash pipeline backpressure elasticsearch output PQ full"`, `"kibana dashboard slow elasticsearch query performance"`

## Output
Report: identified bottleneck layer, metric values vs thresholds, backpressure chain status, and targeted fix (scale, tune, or reduce load) for the confirmed bottleneck layer.
