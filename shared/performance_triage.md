# Performance Triage

**Purpose**: Isolate the bottleneck layer in the Elastic Stack data path quickly.

## Data Path
```
Source → Beats/Agent → [Logstash] → ES Ingest → ES Write → ES Search → Kibana
```

## Step 1 — Identify the Bottleneck Layer
Check each layer for the first sign of queuing or backlog:

| Layer | Signal |
|---|---|
| Beats/Agent | `output busy`, `queue full`, `backpressure` in log |
| Logstash PQ | PQ growing; events.out << events.in |
| ES write thread pool | `queue > 0` or `rejected > 0` |
| ES search thread pool | `queue > 0` or `rejected > 0` |
| Kibana | `resp_time_avg` > 2000 ms |

## Step 2 — ES Node Performance Signals
| Metric | Warning | Critical |
|---|---|---|
| CPU % | > 70% sustained | > 90% |
| Heap % | > 75% | > 85% |
| GC overhead (old gen) | > 10% of elapsed | > 30% |
| Write queue depth | > 50 | > 200 |
| Search queue depth | > 50 | > 200 |

## Step 3 — Hot Thread Interpretation
| Stack Frame | Indicates |
|---|---|
| `IndexingMemoryController`, `InternalEngine` | Indexing pressure |
| `LuceneSearcher`, `BucketCollector` | Heavy search/aggregation |
| `GarbageCollector` | Heap pressure |
| `PainlessScript` | Expensive scripts |
| `SegmentMerger` | Merge storm |
| `Netty`, `TcpTransport` | Network I/O |

## Step 4 — Slow Log Analysis
- Enable search slow log if not active: `slowlog.threshold.query.warn: 2s`
- Sort by duration; focus on the slowest 10 queries
- Identify index, query type, and aggregation causing delay

## Step 5 — Backpressure Propagation
When ES rejects writes, backpressure propagates upstream:
```
ES rejects → Logstash output slows → PQ fills → Beats blocks → Source queues
```
Fix the ES-side bottleneck first; everything else will drain automatically.

## Step 6 — Capacity Signals
| Signal | Action |
|---|---|
| CPU > 70% sustained all data nodes | Add data nodes |
| Heap > 75% on multiple nodes | Add nodes or increase heap (max ~30 GB) |
| Write queue > 50 sustained | Add nodes or reduce shard count |
| Disk > 75% any node | Add storage |
| Shards/node > 20× heap_GB | Reduce shard count |
| Logstash PQ > 80% of max_bytes | Add Logstash workers |

## Step 7 — Dashboard / Kibana Slowness
- Check if ES query is slow (Network tab shows `/api/` call > 1s)
- Check if browser rendering is slow (fast API, slow page = frontend bottleneck)
- Heavy patterns: `terms` on high-cardinality field, wide time range, runtime fields in aggregations
