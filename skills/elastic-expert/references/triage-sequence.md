# Elastic Triage Sequence

Follow these phases in order to ensure no layer is missed.

## Phase 1: Scope and Context
- Identify products involved, versions, deployment model, severity, user-visible impact.
- Determine issue category: Availability, Performance, Ingest, Health, Upgrade, Security, Lifecycle, Platform.
- Check for recent changes: Upgrades, restarts, topology changes, scaling, cert rotation, pipeline changes.

## Phase 2: Elasticsearch Core Health
- Cluster health/status & node roles.
- Master stability & formation.
- Shard allocation & unassigned shards.
- Storage/Disk watermarks.
- JVM heap, GC, CPU, thread pools, circuit breakers.
- Indexing/Search rejections.
- Shard sizing/distribution/imbalance.

## Phase 3: Performance and Optimization
- Evaluate search/indexing latency and bottlenecks.
- Check queue buildup and backpressure.
- Identify hot spotting and oversharding.
- Analyze expensive queries/mappings.
- Distinguish between acute incidents and structural optimization needs.

## Phase 4: Stack Components
Analyze in order:
1. Kibana
2. Logstash / Ingest Pipelines
3. Fleet / Agent
4. APM Server
5. Beats
Determine if failure is independent or a downstream effect of Elasticsearch health.

## Phase 5: Platform Analysis
Tailor analysis to the identified model (Self-managed, ECK, ECE, ECH). Look for orchestration signals (K8s events, ECE plans, Cloud instance health).

## Phase 6: Upgrade & Compatibility
Check for mixed-version states, deprecated settings, plugin conflicts, and migration failures.

## Phase 7: Diagnostics Collection
Document collection failures separately; do not let them obscure the primary root cause.
