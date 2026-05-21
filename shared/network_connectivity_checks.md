# Network Connectivity Checks

**Purpose**: Structured workflow to isolate network-layer failures across Elastic Stack components.

## Port Reference
| Component | Port | Used By |
|---|---|---|
| ES HTTP | 9200 | Kibana, Beats, Logstash output |
| ES Transport | 9300 | ES node-to-node only — no LB |
| Kibana | 5601 | Browser, alerting callbacks |
| Logstash Beats input | 5044 | Beats |
| Fleet Server | 8220 | Elastic Agent |
| APM Server | 8200 | APM agents |

## Step 1 — Confirm the Service Is Listening
On the target host: check that the process is bound to the expected port.
- If not listening: service is down or bound to wrong interface

## Step 2 — Test Reachability from Source
From the source component's host: test TCP connectivity to the target port.
- `refused` = service not listening or firewall rejecting (RST)
- `timeout` = firewall dropping silently (no RST)
- `no route` = routing or subnet issue

## Step 3 — DNS Resolution
From the source host: resolve the target hostname.
- Confirm forward lookup returns the expected IP
- Confirm reverse lookup matches forward (asymmetric DNS = peer discovery failure)
- Check `/etc/hosts` overrides

## Step 4 — Firewall / Security Group
- Is the required port open between source subnet and target subnet?
- Are security group rules applied to both the instance and the VPC/subnet level?
- For ES transport (9300): must be direct; no LB in path

## Step 5 — Load Balancer Requirements
- HTTP (9200): LB OK; no session affinity needed; health check `GET /`
- Transport (9300): NO LB — direct node-to-node only
- LB timeout must be ≥ ES `http.keep_alive_time` (default 5 min)

## Step 6 — Latency and Packet Loss
- Acceptable: < 1 ms RTT between ES nodes
- Risk: > 1% packet loss → missed heartbeats → master election disruption
- WAN / CCS: < 50 ms acceptable; > 200 ms = risk

## Common Causes by Symptom
| Symptom | Check |
|---|---|
| `ECONNREFUSED` | Service not listening on port |
| Connection timeout | Silent firewall DROP rule |
| Peer discovery fails | Asymmetric DNS or transport port blocked |
| Cross-cluster (CCS) fails | Transport port 9300 blocked between clusters |
| Kibana "not ready" | ES unreachable on 9200 |
| Beats not shipping | Logstash 5044 or ES 9200 blocked |
