# Required Triage Sequence

Follow this sequence to analyze the Elastic Stack on ECE:

## 1. Scope and Context
- Identify impacted Elastic components, versions, ECE version, container runtime, OS version, severity, and user-visible impact.
- Determine if there was a recent upgrade, rolling restart, scaling event, allocator move, plan change, cert rotation, template/pipeline change, or workload increase.

## 2. Elasticsearch Core Health
- Evaluate cluster health, node roles, master stability, unassigned shards, allocation blockers.
- Evaluate disk watermarks, JVM heap, GC, CPU, circuit breakers, indexing/search rejections.
- Evaluate shard sizing, imbalance, recovery/relocation state, and version compatibility.

## 3. Performance and Optimization Analysis
- Evaluate slow search/indexing, ingest latency, queue buildup/backpressure.
- Identify shard imbalance, hot spotting, oversharding/undersharding, expensive queries.
- Check storage latency, CPU saturation, heap pressure, and distinguish between immediate break/fix and structural optimizations.

## 4. Stack Components
- Evaluate Kibana, Logstash, Fleet, APM, Beats, Enterprise Search.
- Determine if healthy, failing due to ES being unhealthy, misconfigured, or if auth/TLS/connectivity is the blocker.
- Check if ECE platform, container runtime, or OS is preventing startup/readiness.

## 5. ECE Platform Analysis
- Evaluate allocator capacity and placement constraints.
- Evaluate proxy health, routing, route server health, route/service forwarder health.
- Evaluate deployment plan failures, instance config mismatches, storage pressure on allocators.
- Evaluate ZooKeeper health, TLS/certificates (expiration/trust), FRC container health, control-plane symptoms.

## 6. Container Log and Runtime Analysis
- Evaluate container runtime health, daemon/service availability, failed/restarting containers, image pull/startup failures.
- Check container log patterns (fatal exceptions, crash loops, readiness failures).
- Check cgroup/resource limits, FRC health, and proxy/route server/forwarder container logs.

## 7. Docker / Podman / OS Analysis
- Evaluate disk fullness, inode exhaustion, filesystem latency.
- Evaluate memory pressure, swap, OOM events, CPU saturation/steal time.
- Evaluate network reachability, DNS, port binding, firewalls.
- Evaluate kernel limits, ulimits, vm settings, time skew, OS service failures.

## 8. Upgrade and Post-Upgrade Analysis
- Evaluate mixed-version states, unsupported combinations, deprecated settings.
- Evaluate deployment plan/rolling upgrade stalls, Kibana migration failures.
- Evaluate if performance regressions were caused by the upgrade itself or latent pre-existing issues exposed by the upgrade.

## 9. Diagnostics Collection Issues
- Keep collection-time failures in a separate section. Do not let them dominate unless they blocked diagnosis or are clearly causal.
