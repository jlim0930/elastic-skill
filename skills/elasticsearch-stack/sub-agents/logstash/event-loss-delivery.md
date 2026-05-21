---
name: ls-event-loss-delivery
description: Diagnoses Logstash missing or losing events, duplicate events, at-least-once vs at-most-once delivery guarantees, dead letter queue usage and replay, persistent queue corruption or sizing issues, and shutdown/restart causing unexpected event replay or loss.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# LS — Event Loss / Delivery Guarantees

**Purpose**: Identify why events are missing or duplicated, what delivery guarantee is configured, and how to recover lost events.

## Use When
- Events counted at input but missing in Elasticsearch
- Duplicate documents appearing in Elasticsearch
- Dead letter queue growing unexpectedly
- PQ corruption preventing Logstash from starting

## Do Not Use When
- Events not arriving at input → logstash/input-connectivity
- Events being filtered/dropped intentionally → logstash/filter-parsing

## Inputs Needed
- Queue type in use (memory vs persisted)
- `events.in` vs `events.out` vs `events.filtered` counts from Node Stats API
- DLQ size and error type
- Shutdown method used (graceful vs kill -9)

## Diagnostic Logic

### Event Accounting
- `in` = events received from input
- `out` = events sent to output
- `filtered` = events intentionally dropped by filter (`drop {}` or routing)
- `queue_push_failed` = events dropped because memory queue was full
- If `in` ≠ `out + filtered + queue_push_failed` → unexplained loss; investigate pipeline errors

### Delivery Guarantee Model
| Queue Type | Guarantee | Loss Risk |
|---|---|---|
| `memory` (default) | At-most-once | Events in memory lost on crash or SIGKILL |
| `persisted` (PQ) | At-least-once | Survives restart; events replayed on recovery |

- Exactly-once is NOT available in Logstash — use idempotent writes in ES output instead
- Idempotent pattern: `fingerprint` filter generates deterministic ID → `document_id` in ES output

### Dead Letter Queue (DLQ)
- DLQ stores events that fail all output retries (permanent failures: 400 mapping conflict, 413 too large)
- DLQ growing = output permanently rejecting some events
- Check: mapping conflicts in ES (wrong field type), documents too large, invalid fields
- Replay DLQ events using `logstash-input-dead_letter_queue` plugin with date range filter

### Persistent Queue State
- PQ `queue_size_bytes` approaching `max_queue_size_bytes` → events will be blocked (backpressure to input)
- PQ not draining → output is slow or failed (fix downstream ES first)
- Size recommendation: enough capacity for at least 1 hour of peak throughput × avg event size

### PQ Corruption
- `CorruptStateException` on startup → PQ corrupted (usually from unclean shutdown on full disk)
- Repair tool (Logstash 7.12+): `pqrepair <queue_dir>/<pipeline_id>/`
- If repair fails: backup queue directory, delete it, restart (events in PQ lost)
- Prevention: ensure `queue.max_bytes` < available disk space

### Duplicate Events
| Cause | Fix |
|---|---|
| Memory queue + SIGKILL → upstream replays | Use PQ or idempotent writes |
| PQ + restart without idempotent output | Use `document_id` in ES output |
| Kafka rebalance replays partitions | Ensure stable `consumer_group` ID |
| Multiple Logstash nodes consuming same input | Coordinate consumer groups |

### Shutdown Behavior
- SIGTERM (graceful) → Logstash drains queue before exiting; no memory queue loss
- SIGKILL / `kill -9` → process killed immediately; memory queue events lost; PQ may need repair
- `pipeline.unsafe_shutdown: false` (default) → waits for pipeline drain before exit

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for DLQ, queue, delivery error patterns
→ [performance_triage](../../../../shared/performance_triage.md) — trace backpressure chain to root cause

## KCS Queries
`"logstash event loss missing data pipeline"`, `"logstash duplicate events fingerprint idempotent"`, `"dead letter queue logstash replay mapping conflict"`, `"persistent queue corruption repair logstash"`

## Output
Report: queue type, event count discrepancy (in vs out), DLQ size and error type, root cause (mapping conflict / PQ corrupt / crash / duplicate), fix.
