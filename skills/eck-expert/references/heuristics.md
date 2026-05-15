# ECK and Kubernetes Signals

## ECK / Kubernetes Signals
- Repeated restarts, OOMKilled, Pending, or FailedScheduling
- PVC unbound or storage latency / throttling
- Reconciliation failures in ECK operator logs
- CrashLoopBackOff with OOM: increase resource limits in the Elasticsearch CR

## Issue Families
- Cluster health and stability
- Sharding, balance, and data layout
- Resource pressure (Heap, CPU, Disk)
- Ingest latency and pipeline bottlenecks
- Security / TLS / Auth
- ECK/Operator and K8s orchestration
- Upgrades and compatibility
