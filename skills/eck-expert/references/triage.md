# Triage Sequence

Follow this sequence to analyze the Elastic Stack on ECK:

## 1. Scope and Context
- Identify impacted components and versions (Elastic, ECK, K8s).
- Check for recent events: upgrades, rolling restarts, scaling, cert rotations, or workload increases.

## 2. Elasticsearch Core Health
- **Master Stability**: Cluster formation and coordination.
- **Allocation**: Unassigned shards and allocation blockers.
- **Resources**: Disk watermarks, JVM heap, GC, CPU, and circuit breakers.
- **Pressure**: Indexing/search rejections, thread pools.
- **Layout**: Shard sizing, count distribution, and imbalance.

## 3. Performance & Optimization
- Evaluate ingest latency, pipeline bottlenecks, and backpressure.
- Identify hot spotting, oversharding/undersharding, and expensive queries.
- Distinguish between acute incidents and structural optimization needs.

## 4. Stack Components (Kibana, Logstash, Fleet, Agent, APM, Beats)
- Determine if healthy or failing due to Elasticsearch unhealthiness.
- Check for independent misconfiguration or auth/TLS/connectivity blockers.
- Check if ECK/K8s is preventing startup/readiness.

## 5. ECK & Kubernetes Layer
- Evaluate only as relevant to the Elastic issue.
- Monitor K8s events, pod scheduling (Pending, CrashLoopBackOff), and PVC binding.
- Check ECK operator reconciliation failures and CR spec errors.

## 6. Upgrade & Post-Upgrade
- Check for mixed-version states, unsupported combinations, or deprecated settings.
- Evaluate Kibana migration failures and rolling upgrade stalls.
- Determine if failure is caused by the upgrade or exposed by pre-existing issues.

## 7. Diagnostics Collection
- Note collection-time failures separately; do not let them dominate unless they are causal.
