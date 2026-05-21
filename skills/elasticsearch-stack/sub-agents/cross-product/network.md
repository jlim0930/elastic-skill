---
name: cross-network
description: Diagnoses cross-product network issues across the Elastic Stack including port reachability between components, firewall and security group requirements, DNS resolution and asymmetric DNS causing peer discovery failures, reverse proxy and load balancer misconfiguration, inter-node latency and packet loss thresholds, and cross-cluster connectivity for CCS/CCR.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Cross-Product — Network

**Purpose**: Isolate connectivity failures between stack components by layer (DNS → port → TLS → auth) and prescribe the network fix.

## Use When
- Component cannot reach another component (ECONNREFUSED, timeout, no route)
- ES peer discovery failing (master not found, nodes not joining)
- CCS/CCR remote cluster not connecting
- Load balancer or proxy causing intermittent failures

## Do Not Use When
- TLS handshake error (port is open but TLS fails) → cross-product/certificate-tls
- Auth error after connection succeeds → component-specific security sub-agent

## Inputs Needed
- Source component and destination component (e.g., Kibana→ES, Beats→Logstash)
- Error message (connection refused / timed out / no route to host)
- Network topology (direct, via LB, via proxy, cross-DC)

## Diagnostic Logic

### Port Reference Table
| Component | Port | Direction | Notes |
|---|---|---|---|
| ES HTTP | 9200 | Clients→ES | REST API, Kibana, Beats, Logstash |
| ES Transport | 9300 | ES↔ES | Node-to-node; NEVER put LB here |
| Kibana | 5601 | Users→Kibana | Browser and API |
| Logstash Beats input | 5044 | Beats→Logstash | TLS strongly recommended |
| Fleet Server | 8220 | Agents→Fleet | HTTPS |
| APM Server | 8200 | APM agents→APM | HTTPS |

### Connection Failure Classification
| Result | Meaning |
|---|---|
| `Connection refused` | Service not listening, or firewall rejecting with RST |
| `Connection timed out` | Firewall silently dropping (no RST) |
| `No route to host` | Routing/subnet issue or firewall DROP |
| `Connected successfully` | Port open — check TLS and auth next |

### DNS Resolution Check
- Asymmetric DNS causes ES peer discovery failures: Node A resolves itself as `10.0.0.1` but Node B resolves `node-a` to `10.0.0.2` → peers cannot find each other
- Check: forward lookup from each node; reverse lookup must match forward
- Check `/etc/hosts` overrides that may conflict with DNS
- ES `network.publish_host` must be resolvable by all other nodes

### Firewall / Security Group Requirements
| Rule | Source → Destination | Port |
|---|---|---|
| ES HTTP | Kibana, Logstash, Beats, Monitoring → ES | TCP 9200 |
| ES Transport | ES node → ES node | TCP 9300 |
| Kibana UI | Users, Reporting → Kibana | TCP 5601 |
| Logstash Beats | Filebeat/Metricbeat → Logstash | TCP 5044 |
| Fleet Server | Elastic Agents → Fleet | TCP 8220 |

### Load Balancer Rules
- LB on port 9200 (HTTP) = OK
- LB on port 9300 (transport) = **never** — transport requires direct node-to-node
- LB health check: `GET /` or `GET /_cluster/health` (returns 200 for healthy nodes)
- LB timeout must be ≥ ES `http.keep_alive` timeout (default 5 min)
- No session affinity required for ES HTTP (stateless)

### Inter-Node Latency Thresholds
| Metric | Acceptable | Risk | Critical |
|---|---|---|---|
| RTT between ES nodes | < 1 ms | 1–5 ms | > 5 ms |
| RTT for CCS (WAN) | < 50 ms | 50–200 ms | > 200 ms |
| Packet loss | 0% | < 0.1% | ≥ 1% |

Packet loss ≥ 1% = missed heartbeats → master election disruption.

### Cross-Cluster Connectivity (CCS/CCR)
- Transport port 9300 must be open between clusters
- TLS must be configured on both clusters (required in 8.x)
- Remote cluster version must be ≤ local cluster version (older remote, newer local = OK; reverse = not supported)
- Check: `GET /_remote/info` shows `connected: true/false` and `mode` (sniff or proxy)

## Shared Skills
→ [network_connectivity_checks](../../../../shared/network_connectivity_checks.md) — port reachability, DNS, firewall diagnostic steps
→ [log_filtering](../../../../shared/log_filtering.md) — filter for connection refused, timeout, no route patterns across component logs

## KCS Queries
`"elasticsearch port connectivity firewall 9200 9300 blocked"`, `"kibana elasticsearch ECONNREFUSED connection refused"`, `"elasticsearch peer discovery DNS asymmetric publish host"`, `"cross-cluster search CCS remote cluster not connected transport"`

## Output
Report: failed component pair, connection failure type (refused/timeout/DNS), port/firewall root cause, and fix (open port, fix DNS, remove LB from transport, or adjust proxy config).
