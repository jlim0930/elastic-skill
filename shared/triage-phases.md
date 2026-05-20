# Common Triage Phases

Load only for multi-domain or unclear issues. Single-domain issues go directly to the matching sub-agent.

## Phase 1: Scope and Context
- Products involved, versions, deployment model (self-managed / ECH / ECE / ECK).
- Severity and user-visible impact (data loss, unavailability, latency, partial degradation).
- Recent changes: upgrades, rolling restarts, scaling, cert rotation, pipeline or config changes.

## Phase 2: Elasticsearch Core Health
- Cluster status (`_cluster/health`), master stability, node roles.
- Unassigned shards and allocation blockers (`_cluster/allocation/explain`).
- Disk watermarks, JVM heap, GC activity, CPU, circuit breakers.
- Thread pool queue depth and rejections.
- Shard sizing: oversharded (<100 MB), undersized (>50 GB), imbalanced.

## Phase 3: Performance and Optimization
- Search/indexing latency, bulk queue buildup, backpressure.
- Hot spotting, oversharding, expensive queries, segment pressure.
- Distinguish: acute incident (immediate fix) vs. structural issue (optimization).

## Phase 4: Stack Components
- Kibana → Logstash/Ingest Pipelines → Fleet/Agent → APM Server → Beats.
- Determine if failure is independent or downstream of Elasticsearch health.
- Check TLS/auth/connectivity before assuming application-level misconfiguration.

## Phase 5: Platform Layer
- Self-managed: OS limits, disk, kernel, DNS.
- ECK: K8s events, pod scheduling, PVC, operator reconciliation.
- ECE: ZooKeeper, allocators, proxy/route server, container runtime.
- ECH: deployment plan, autoscaling, console signals.

## Phase 6: Upgrade and Compatibility
- Mixed-version states, deprecated settings, plugin conflicts.
- Rolling upgrade stalls, Kibana migration failures.
- Distinguish: regression caused by upgrade vs. pre-existing issue exposed by upgrade.

## Phase 7: Diagnostics Gaps
- Note collection-time failures in a separate section. Do not let them obscure primary root cause.

## Phase 8: Output
Format the response using [output-format.md](output-format.md).
