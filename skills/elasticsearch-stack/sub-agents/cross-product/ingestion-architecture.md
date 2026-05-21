---
name: cross-ingestion-architecture
description: Diagnoses cross-product ingestion architecture issues including Beats/Agent to Logstash to Elasticsearch flow tracing, ingest pipeline vs Logstash filter decision guidance, ECS field normalization gaps causing Kibana integration dashboard failures, data stream naming and rollover sizing, retry and buffering strategy selection, multi-destination routing, and Agent vs Beats architecture decisions.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Cross-Product — Ingestion Architecture

**Purpose**: Trace the actual data path, identify where data is lost or misrouted, and guide architecture decisions (Beats vs Agent, ingest pipeline vs Logstash, buffering strategy).

## Use When
- Data present at source but not in ES (unknown which component is dropping it)
- Integration dashboards empty despite data in ES (ECS field mismatch)
- Architecture decision: which ingestion pattern to use
- Routing data to multiple destinations or clusters

## Do Not Use When
- Confirmed Logstash pipeline issue → logstash sub-agents
- Confirmed ES ingest pipeline failure → es/ingest-pipeline
- Performance bottleneck already identified → cross-product/performance-triage

## Inputs Needed
- Current architecture: what is the source, what ships the data, does Logstash sit in path
- Data stream or index name where data should arrive
- Whether integration dashboards (Fleet/Kibana integrations) are expected to work

## Diagnostic Logic

### Common Data Path Architectures
| Pattern | When to Use |
|---|---|
| Beats → ES (direct) | Simple use case, no transformation needed |
| Beats → Logstash → ES | Need PQ buffering, complex filtering, or fan-out |
| Elastic Agent → Fleet Server → ES | Recommended for standard integrations (managed) |
| Elastic Agent → Logstash → ES | Fleet-managed agents needing PQ buffering |
| Beats → Kafka → Logstash → ES | High-volume; durable queue independent of ES availability |

### Ingest Pipeline vs Logstash Filter Decision
| Consideration | Use ES Ingest Pipeline | Use Logstash Filter |
|---|---|---|
| Transformation complexity | Simple (dissect, grok, rename, set) | Complex (multi-step, loops) |
| External calls needed | No (except enrich) | Yes (HTTP filter, external lookups) |
| Buffering / at-least-once needed | No | Yes (Logstash PQ) |
| Routing to different indices/clusters | No | Yes |
| Custom scripting | Painless only | Ruby (full language) |
| Managed by Fleet | Yes (integrations use pipelines) | No |
| Throughput priority | Higher (runs on ES ingest nodes) | Lower (Logstash as bottleneck) |

### ECS Field Requirements
Missing ECS fields cause Kibana integration dashboards, ML jobs, and security rules to fail silently.

| Field | Type | Required For |
|---|---|---|
| `@timestamp` | date | Time picker and all time-based views |
| `event.dataset` | keyword | Integration dashboard filtering |
| `event.module` | keyword | Kibana integration grouping |
| `host.name` | keyword | Infrastructure views |
| `message` | text | Full-text search in Discover |
| `source.ip` / `destination.ip` | ip | Security network maps |

Common ECS mistakes:
| Wrong Field | Correct Field | Impact |
|---|---|---|
| `timestamp` | `@timestamp` | Time picker broken |
| `hostname` | `host.name` | Infrastructure views empty |
| `src_ip` | `source.ip` | Security network map broken |
| `level` | `log.level` | Log severity filter broken |

### Data Stream Naming Convention
Format: `<type>-<dataset>-<namespace>` (e.g., `logs-nginx.access-production`)
- `type`: `logs`, `metrics`, or `traces`
- `dataset`: dot-separated (e.g., `nginx.access`, `system.cpu`)
- `namespace`: environment or team (e.g., `production`, `staging`)

Backing index sizing targets: 10–50 GB per backing index; adjust ILM rollover conditions.

### Buffering and Retry Strategy
| Component | Buffer Type | Durability |
|---|---|---|
| Beats (no PQ) | In-memory only | Events lost on process restart |
| Logstash memory queue | In-memory | Events lost on Logstash restart |
| Logstash PQ (`persisted`) | Disk-backed | Events survive restart; at-least-once |
| Elastic Agent | Built-in disk queue | Configurable `queue.disk.max_size` |
| Kafka (external) | Distributed log | Durable; independent of ES availability |

- PQ sizing: expected ES outage duration × ingest rate
- PQ full = backpressure propagates upstream to Beats; fix ES before enlarging PQ
- DLQ (Dead Letter Queue): captures events permanently rejected by ES (mapping conflicts, etc.)

### Elastic Agent vs Beats Decision
| Scenario | Recommendation |
|---|---|
| Standard integrations (nginx, system, AWS) | Elastic Agent — maintained integrations, auto-updates |
| Custom log parsing with complex Grok | Filebeat + Logstash (or ingest pipeline) |
| Multiple data sources on one host | Elastic Agent — single process, centrally managed |
| Air-gapped, no internet access | Beats may be simpler (no Fleet Server required) |
| PQ-level buffering needed | Logstash in the path (Elastic Agent → Logstash → ES) |
| Kubernetes pod log collection | Elastic Agent DaemonSet with Fleet |

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — trace data path gaps in Beats, Logstash, and ES logs
→ [error_pattern_matching](../../../../shared/error_pattern_matching.md) — classify routing and field errors before diagnosing architecture

## KCS Queries
`"beats agent logstash elasticsearch ingestion architecture data path"`, `"ingest pipeline vs logstash filter when to use decision"`, `"ECS normalization elastic common schema dashboard empty"`, `"data stream naming convention rollover design logstash beats"`

## Output
Report: actual data path vs expected path, where data is lost or misrouted, ECS field gap (if any), buffering strategy recommendation, and architecture fix.
