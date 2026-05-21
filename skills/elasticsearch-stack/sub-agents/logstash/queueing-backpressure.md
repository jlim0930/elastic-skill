---
name: ls-queueing-backpressure
description: Diagnoses Logstash persistent queue page file issues and sizing, memory queue saturation, downstream Elasticsearch unavailability causing queue buildup, Kafka-to-Logstash-to-ES lag chains, queue growth diagnostics, and backpressure propagation across pipeline stages.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# LS — Queueing & Backpressure

**Purpose**: Identify where in the Logstash-to-Elasticsearch pipeline the backpressure originates, and prescribe the fix.

## Use When
- Logstash queue growing without draining
- Kafka consumer lag increasing while Logstash is running
- Beats senders timing out or backing off
- PQ disk consuming more space over time

## Do Not Use When
- Queue growing because input is misconfigured → logstash/input-connectivity
- Queue growing because of mapping errors → logstash/elasticsearch-output
- ES health is the issue → es/cluster-health or es/indexing-performance first

## Inputs Needed
- Queue type (memory or persisted)
- PQ size vs `queue.max_bytes` from Node Stats API
- `push_duration_in_millis` trend from Node Stats API
- ES write thread pool state

## Diagnostic Logic

### Backpressure Propagation Chain
```
ES slow/rejecting → Logstash output blocked → pipeline workers blocked → queue can't drain
→ push_duration high → input blocked → Beats backs off → Kafka lag grows
```
Fix at the BOTTOM of the chain first. Fixing Logstash throughput while ES is rejecting makes things worse.

### Root Cause Identification
1. Is ES rejecting writes? (429s in Logstash output log) → fix ES first
2. Is `events.out` rate dropping? → output is blocked
3. Is `push_duration_in_millis` growing? → queue can't drain fast enough
4. Is Kafka consumer lag growing? → propagated backpressure from below

### Queue Type Comparison
| Aspect | Memory Queue | Persistent Queue (PQ) |
|---|---|---|
| Data loss on crash | Yes — all in-memory events lost | No — survives restart |
| Visible metrics | Limited (JVM heap) | Full size/space metrics |
| Disk I/O overhead | None | Yes — adds latency |
| Beats backpressure | Yes (lumberjack backoff) | Yes (same) |

### PQ Sizing
- PQ at `max_queue_size_bytes` → events blocked; input backs up
- Size formula: `events/sec × outage_seconds × avg_event_bytes`
- Example: 10,000 eps × 3600s × 500 bytes = ~17 GB → set `queue.max_bytes: 20gb`
- Changing `queue.max_bytes` requires Logstash restart (hot reload not supported)

### PQ Page File Health
- Many large `page.*.head` files not being deleted → PQ not draining (output stalled)
- Checkpoint files lagging behind page files → PQ processing slowly
- Check PQ disk consumption: inspect page file sizes sorted by size

### Memory Queue Saturation
- No visible queue size metric (events are in JVM heap)
- Input thread blocks in `push(event)` when queue is full
- Beats sees backpressure → exponential backoff on send
- Kafka consumer stops fetching → lag grows
- Fix: switch to PQ for resilience, or fix downstream ES

### Downstream ES Unavailable
- Logstash retries indefinitely when ES is down (correct behavior)
- PQ buffers all events during outage
- Memory queue fills up and blocks input — events not dropped but new ones blocked at source
- When ES recovers: Logstash drains PQ automatically

### Emergency Queue Full
1. Fix downstream ES (root cause)
2. If PQ is full and needs more space: stop Logstash, increase `queue.max_bytes`, restart
3. Clearing the queue (data loss): stop Logstash, delete PQ directory for pipeline, restart

## Shared Skills
→ [performance_triage](../../../../shared/performance_triage.md) — full backpressure chain diagnosis
→ [log_filtering](../../../../shared/log_filtering.md) — filter for queue full, push blocked, backpressure patterns

## KCS Queries
`"logstash persistent queue full backpressure"`, `"logstash backpressure elasticsearch unavailable queue"`, `"logstash kafka lag pipeline queue buildup"`, `"logstash queue growing not draining"`

## Output
Report: queue type, current size vs max, root cause layer (ES rejection / filter slow / PQ I/O), fix order.
