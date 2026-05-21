---
name: es-network-transport
description: Diagnoses Elasticsearch inter-node connectivity failures, transport TLS handshake failures, CCS/CCR connectivity issues, packet loss or latency causing cluster instability, DNS problems, load balancer interference with transport layer, and publish address mismatches.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — Network & Transport

**Purpose**: Isolate network-layer failures affecting cluster stability, inter-node communication, or cross-cluster connectivity.

## Use When
- Nodes disconnecting or failing to join
- `NodeDisconnectedException` or `ConnectTransportException` in logs
- CCS/CCR shows `connected: false`
- Cluster instability without heap or disk cause

## Do Not Use When
- TLS certificate errors (not connectivity) → es/tls-certificates
- Node is down due to OOM or GC → es/jvm-memory-gc

## Inputs Needed
- Exception names from ES logs
- Transport port (9300) reachability between nodes
- DNS resolution results for node hostnames
- Network path (on-prem, VPC, cross-region?)

## Diagnostic Logic

### Transport Exception Classification
| Exception | Cause | First Check |
|---|---|---|
| `ReceiveTimeoutTransportException` | Slow node response (GC pause, I/O) | Heap %, GC log, I/O wait |
| `NodeDisconnectedException` | Node left cluster during request | Cluster stability logs |
| `ConnectTransportException` | Cannot connect to transport address | Port 9300 open? Firewall? |
| `NotMasterException` | Request sent to non-master | Master stability |

### Port Reachability
- ES nodes must reach each other on port 9300 (transport)
- Load balancers must NEVER sit in front of port 9300 — only port 9200 (HTTP)
- LBs on transport → intermittent `ReceiveTimeoutTransportException` and routing failures
- Firewall blocking 9300 → node cannot join cluster

### DNS
- Asymmetric DNS (forward ≠ reverse) causes peer discovery failures
- Use IPs in `discovery.seed_hosts` for predictability
- `cluster.name` mismatch → nodes silently refuse to join each other
- `network.publish_host` must be reachable from all other nodes

### Packet Loss
- > 1% packet loss = cluster instability risk (heartbeat timeouts, election disruption)
- > 10 ms RTT between ES nodes = increased fault detection false positives
- Check for network retransmits at OS level

### Cross-Cluster (CCS/CCR)
- Transport port 9300 must be open between clusters
- TLS must be configured consistently (both on or both off)
- Remote cluster must have `remote_cluster_client` role
- Verify seed node list in `cluster.remote.<name>.seeds`

## Shared Skills
→ [network_connectivity_checks](../../../../shared/network_connectivity_checks.md) — port reachability, DNS, LB rules
→ [tls_certificate_checks](../../../../shared/tls_certificate_checks.md) — if TLS handshake errors are in the exception
→ [log_filtering](../../../../shared/log_filtering.md) — filter for transport exception names

## KCS Queries
`"transport TLS handshake failed elasticsearch"`, `"NodeDisconnectedException ReceiveTimeoutTransportException"`, `"cross cluster search connectivity remote"`, `"load balancer elasticsearch transport"`

## Output
Report: exception type, affected node pair, root cause (port/TLS/DNS/LB/packet loss), fix.
