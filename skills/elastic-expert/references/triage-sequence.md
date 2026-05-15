# Elastic Triage Sequence

Load this only for complex or multi-domain issues. For single-domain problems use Quick Route in SKILL.md.

## Phase 1: Scope and Context
- Products, versions, deployment model, severity, user-visible impact.
- Issue category: Availability, Performance, Ingest, Health, Upgrade, Security, Lifecycle, Platform.
- Recent changes: upgrades, restarts, scaling, cert rotation, pipeline changes.

## Phase 2: Elasticsearch Core Health
- Cluster health, node roles, master stability, shard allocation, unassigned shards.
- Disk watermarks, JVM heap, GC, CPU, thread pools, circuit breakers, indexing/search rejections.
- Shard sizing and distribution. Critical thresholds: heap >85%, CPU sustained >90%, disk near flood_stage.

## Phase 3: Performance and Optimization
- Search/indexing latency, queue buildup, backpressure, hot spotting, oversharding, expensive queries.
- Distinguish acute incident vs. structural optimization.

## Phase 4: Stack Components
Kibana → Logstash/Ingest Pipelines → Fleet/Agent → APM Server → Beats.
Determine if failure is independent or downstream of Elasticsearch health.

## Phase 5: Platform Analysis
Tailor to deployment (Self-managed, ECK, ECE, ECH). Check orchestration signals: K8s events, ECE plans, Cloud instance health.

## Phase 6: Upgrade & Compatibility
Mixed-version states, deprecated settings, plugin conflicts, migration failures.

## Phase 7: Diagnostics Collection
Document collection failures separately; do not let them obscure the primary root cause.

## Phase 8: Output
Format the final analysis using [assets/analysis-template.md](assets/analysis-template.md).
