# Platform Specifics

## ECK (Elastic Cloud on Kubernetes)
- Look for: Pod restarts, Pending pods, PVC binding issues, ECK operator reconciliation logs.
- Key signals: OOMKilled, FailedScheduling, Webhook/Cert drift.

## ECE (Elastic Cloud Enterprise)
- Look for: Allocator capacity, Proxy routing health, stuck Plan changes.
- Key signals: Instance configuration mismatches, allocator storage pressure.

## ECH (Elastic Cloud Hosted)
- Look for: Deployment health signals, Traffic filters, Snapshot capacity symptoms.
- Key signals: Plan change failures, zone failures.

## Self-Managed / On-Prem
- Look for: System limits (nproc, nofile), OS resource pressure, DNS/TLS connectivity.
- Key signals: Disk fullness, I/O latency, network reachability.
