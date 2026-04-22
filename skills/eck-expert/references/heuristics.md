# Heuristics and Thresholds

## Critical Thresholds
- **Red Cluster Health**: Critical, especially if primaries are unassigned.
- **Heap Usage**: >85% (Critical), >75% (Warning).
- **CPU Usage**: >90% (Critical).
- **Disk Usage**: High watermark (Allocation risk), Flood stage (Critical/ReadOnly).
- **Rejections**: Search/Write rejections with user impact (Warning/Critical).

## Sharding & Layout
- Very high shard count per node is a risk.
- Tiny shards (<100MB) suggest oversharding.
- Very large shards (>50GB) increase recovery/performance risk.
- Imbalance creates hot nodes and resource contention.

## ECK / Kubernetes Signals
- Repeated restarts, OOMKilled, Pending, or FailedScheduling.
- PVC unbound or storage latency/throttling.
- Reconciliation failures in ECK operator logs.

## Issue Families to Evaluate
- Cluster health and stability.
- Sharding, balance, and data layout.
- Resource pressure (Heap, CPU, Disk).
- Ingest latency and pipeline bottlenecks.
- Security / TLS / Auth.
- ECK/Operator and K8s orchestration.
- Upgrades and compatibility.
