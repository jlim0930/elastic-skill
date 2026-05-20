# Critical Thresholds and Confidence Labels

## Elasticsearch / JVM
- JVM heap: >85% **Critical** | >75% **Warning**
- GC: >30% overhead → memory pressure; combined with heap >80% = emergency
- Circuit breakers: any `tripped` state = Critical until cleared

## CPU and I/O
- CPU: sustained >90% **Critical**
- I/O wait: sustained >30% = storage bottleneck
- Thread pool queue: >100 queued / any rejected = **Warning**; escalating rejections = **Critical**

## Disk
- `high_watermark` (default 90%) = Allocation Risk — no new shards assigned
- `flood_stage` (default 95%) = **Critical** — index becomes read-only
- Monitor inodes separately (`df -i`); can exhaust before bytes

## Cluster Health
- `green` = all shards assigned
- `yellow` = replica shards missing (reads OK; durability reduced)
- `red` = **Critical** — primary shards unassigned; data unavailable

## Shard Sizing
- <100 MB per shard = oversharded (merge and reduce)
- 10–50 GB = optimal for most workloads
- >50 GB = recovery/performance risk
- Cluster total >1,000 shards per GB of heap = oversharded cluster

## ECE Platform
- ZooKeeper `zk_outstanding_requests` > 10 sustained = lag risk
- Allocator disk >80% = placement risk; >90% = **Critical**
- Proxy / route server 5xx rate >1% = routing degradation

## ECH (Elastic Cloud Hosted)
- Plan stuck >4 hours = data migration bottleneck
- Autoscaling blocked = potential data loss risk on scale-down

## ECK (Kubernetes)
- CrashLoopBackOff = **Critical** — pod cannot stabilize
- Pending pod >5 minutes = scheduling failure
- PVC in `Pending` = storage provisioner issue

## Confidence Labels
- **High** — multiple independent sources confirm the same root cause
- **Medium** — single strong source or strong inference from evidence
- **Low** — partial evidence; hypothesis not yet confirmed
