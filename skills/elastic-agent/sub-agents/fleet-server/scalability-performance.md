---
name: fleet-server-scalability-performance
description: Diagnoses Fleet Server overloaded, slow check-ins at scale, action queue delays, resource sizing issues, too many agents per Fleet Server, Elasticsearch latency impacting Fleet responsiveness, and horizontal scaling/HA design questions.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Fleet Server — Scalability & Performance Sub-Agent

Scope: Fleet Server overloaded, slow check-ins at scale, action queue delays, resource sizing, too many agents per Fleet Server, ES latency impacting Fleet responsiveness, horizontal scaling/HA design.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Fleet Server overloaded scale"`, `"Fleet Server slow check-ins agents"`, `"Fleet Server resource sizing"`, `"Fleet Server horizontal scaling HA"`, `"Fleet Server Elasticsearch latency"`.

## Diagnostic Steps

### 1. Fleet Server Resource Usage
```bash
ps aux | grep elastic-agent | grep -v grep | awk '{print "CPU:"$3, "MEM%:"$4, "RSS:"$6}'
# Per-process breakdown
top -b -n1 -p $(pgrep -f elastic-agent | tr '\n' ',') | tail -10
```
Fleet Server capacity:
- Small fleet (< 500 agents): 4 vCPU, 8 GB RAM.
- Medium fleet (< 5,000 agents): 8 vCPU, 16 GB RAM.
- Large fleet (< 20,000 agents): 16 vCPU, 32 GB RAM.

### 2. Check-In Status at Scale
```bash
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/agents?perPage=0" \
  | jq '{total:.total, status:.statusSummary}'
```
High offline% = check-in issues. Track over time to identify drift.

### 3. Fleet Server API Latency
```bash
time curl -s https://<fleet-server>:8220/api/status
```
> 1s response time = Fleet Server under load.
```bash
grep -E "slow|latency|took.*ms\|duration" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -20
```

### 4. Elasticsearch Latency Impact
Fleet Server performs many ES reads/writes per check-in. ES slowness directly increases check-in latency.
```bash
curl -w "Total: %{time_total}s\n" -s -o /dev/null https://<es-host>:9200/_cluster/health
curl -s "http://localhost:9200/_cat/thread_pool/search,write?v&h=name,active,queue,rejected"
```
ES write queue building = Fleet data not being indexed fast enough.

### 5. Action Queue Depth
```bash
curl -s "http://localhost:9200/.fleet-actions*/_count" | jq '.count'
curl -s "http://localhost:9200/.fleet-actions*/_search?size=0&q=type:POLICY_CHANGE&sort=@timestamp:desc" | jq '.hits.total.value'
```
Large pending action count with slow processing = Fleet Server or ES bottleneck.

### 6. Horizontal Scaling (HA)
Run multiple Fleet Server instances for HA:
- Each Fleet Server is an Elastic Agent with a Fleet Server policy.
- All connect to the same Elasticsearch cluster.
- Agents connect to any Fleet Server via a load balancer.
- No state is local to Fleet Server — all state is in ES.
```bash
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/fleet_server_hosts" | jq '.items | length'
```
Current single Fleet Server = SPOF. Add a second Fleet Server behind the same LB.

### 7. Too Many Agents per Fleet Server
Rule of thumb: 1 Fleet Server per 10,000 agents (varies with policy update frequency).
If Fleet Server is at capacity: add more Fleet Server instances (horizontal scale).
```bash
# Count agents per Fleet Server
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/agents?perPage=0" | jq '.total'
```

### 8. Fleet Server Tuning
```bash
elastic-agent inspect --output yaml | grep -A10 "fleet.server:"
```
Tunable parameters (via Fleet Server policy in Kibana):
- `fleet.server.timeouts.checkin`: agent check-in timeout (default 30s).
- `fleet.server.limits.max_connections`: concurrent connections limit.

### 9. KCS + Docs Lookup
Execute retrieval protocol now with Fleet Server resource usage and agent count.

## Token Budget
- Resource usage (`ps aux`) and ES thread pool check give instant capacity signal.
- `jq` on Kibana Fleet API for agent count — faster than log analysis.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
