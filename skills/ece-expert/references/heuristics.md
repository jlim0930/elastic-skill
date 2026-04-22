# Heuristics, Thresholds, and Issue Families

## Critical Thresholds & Heuristics
- **Cluster Health**: Red is critical (especially if primaries unassigned). Yellow is a warning (unless replicas intentionally absent).
- **Heap Usage**: Sustained >85% is critical risk. Sustained >75% is a warning.
- **CPU Usage**: Sustained >90% is critical.
- **Disk Usage**: Above high watermark creates allocation risk. Near flood stage is critical.
- **Rejections**: Search/write rejections with user impact are warning or critical depending on rate.
- **Circuit Breakers**: Parent breaker trips are critical.
- **Lifecycle**: ILM stopped or indices stuck in error are critical if lifecycle is blocked.
- **Shards**: Very high shard count per node is a risk. Tiny shards (<100MB) suggest oversharding. Very large shards (>50GB) increase recovery risk. Imbalance creates hot nodes/latency.

## High-Priority Platform Signals
- Allocator exhaustion
- Failed plan application
- Proxy routing failures
- Route server/forwarder failures
- Certificate expiration
- ZooKeeper instability
- Runtime daemon failures (Docker/Podman)
- Disk exhaustion / OOM events / OS-level service failures

## Common Issue Families to Evaluate
- Elasticsearch cluster health and stability
- Sharding, balance, and data layout
- Resource pressure and storage/allocation
- Performance, optimization, ingest latency
- Security, TLS, auth, certificate expiration/trust
- Upgrades, compatibility, config drift
- ECE platform issues affecting Elastic (ZooKeeper, routing, proxy, FRC)
- Container log, Docker/Podman, and OS/host issues affecting ECE/Elastic
