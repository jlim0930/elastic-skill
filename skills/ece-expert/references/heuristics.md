# ECE Platform Signals and Issue Families

## High-Priority ECE Platform Signals
- Allocator exhaustion or imbalance
- Failed plan application
- Proxy routing failures / route server / forwarder failures
- Certificate expiration (ECE or Elastic layer)
- ZooKeeper instability (leader election, connection loss)
- Runtime daemon failures (Docker / Podman)
- Disk exhaustion / OOM events / OS-level service failures

## Issue Families
- Elasticsearch cluster health and stability
- Sharding, balance, and data layout
- Resource pressure and storage/allocation
- Performance, optimization, ingest latency
- Security, TLS, auth, certificate management
- Upgrades, compatibility, config drift
- ECE platform (ZooKeeper, routing, proxy, FRC, allocators)
- Container log, Docker/Podman, OS/host issues
