---
name: ech-deployment-health
description: Diagnoses ECH deployment health warnings, unhealthy Elasticsearch/Kibana/APM/Fleet instances, instance restart loops, "server is not ready yet", hosted maintenance-related health messages, deployment unavailable after a change, and distinguishing platform-side issues from customer workload issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECH — Deployment Health & Availability Sub-Agent

Scope: Deployment health warnings in cloud console, unhealthy ES/Kibana/APM/Fleet instances, restart loops, "server is not ready yet", hosted maintenance-related health messages, deployment unavailable after a change, service degradation vs customer workload issues.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECH deployment unhealthy"`, `"Elastic Cloud deployment health warning"`, `"Kibana server not ready ECH"`, `"ECH instance restart loop"`, `"hosted deployment unavailable after change"`, `"Elastic Cloud maintenance mode"`.

## Diagnostic Steps

### 1. Read the Health Signal in Cloud Console
The ECH console surfaces health at multiple levels:
- **Deployment-level indicator**: Green / Yellow / Red
- **Instance-level**: Per-resource health (ES nodes, Kibana, APM Server, Enterprise Search, Fleet)
- **Activity log**: Recent plan changes, restarts, and their outcomes

| Signal | Meaning |
|---|---|
| Green | All instances healthy and routing traffic |
| Yellow | At least one instance is unhealthy but deployment is partially serving |
| Red | Deployment is not serving requests |
| `Maintenance mode` | Deliberate; routing disabled while platform performs infrastructure work |
| `Failing` | Instance failing health checks repeatedly |
| `Restarting` | Instance in restart cycle — check if looping |
| `Stopped` | Deployment deliberately stopped by customer |

### 2. Distinguish Platform Issue vs. Customer Workload Issue
This is the most critical triage step. ECH is a shared responsibility model.

**Platform issues (Elastic's responsibility):**
- Instance evicted by the underlying hypervisor or cloud provider
- Zone-wide failures affecting hosted infrastructure (multiple deployments in the same zone affected)
- Plan change initiated by Elastic's automation unexpectedly
- Disk I/O or network problems at the hypervisor or storage layer
- `Maintenance mode` applied by the platform without customer action
- Instance restarted by ECH internal health monitoring

**Workload issues (customer's responsibility):**
- OOM caused by a large query, aggregation, or field data cache loading
- JVM GC pressure from oversharding or heap too small for data volume
- Elasticsearch cluster red due to unassigned shards from customer ILM/config
- Kibana not ready because ES is red (downstream cascade from ES workload issue)
- High CPU from expensive aggregation or wildcard queries

**How to tell the difference:**
```
1. Check Elastic Cloud status page for the region — platform issues affect multiple customers
2. Check if any plan changes were in progress when the issue started
3. Check ES cluster health — workload issues show in ES metrics (heap, GC, shards)
4. If instance restart was brief and self-healed: likely platform maintenance
5. If restart loop correlates with high heap or OOM in logs: workload issue
```

### 3. Elasticsearch Health Check
```bash
# From Kibana Dev Tools or curl
GET _cluster/health
GET _cat/nodes?v&h=name,heap.percent,ram.percent,cpu,disk.used_percent,node.role
GET _cat/shards?v&h=index,shard,prirep,state,unassigned.reason&s=state:desc | head -20
```
- Red cluster = unassigned primary shards → check `unassigned.reason` for root cause
- Yellow cluster = unassigned replicas only → less urgent but investigate
- OOM visible in logs: `OutOfMemoryError`, `java.lang.OutOfMemoryError`

### 4. Kibana "Server Is Not Ready Yet"
This message appears when:
1. ES cluster is red or unavailable (Kibana cannot connect to ES)
2. Kibana migrations are pending or failed
3. Kibana instance itself is crashing or restarting

```bash
# Step 1: Check ES health first — Kibana not ready is usually a downstream effect
GET _cluster/health

# Step 2: If ES is green, check Kibana migration status
GET .kibana_task_manager/_search?size=1

# Step 3: Check Kibana instance status in cloud console
Deployments → [Deployment] → Kibana → instance health
```

Kibana migration failure after an upgrade: the `.kibana` index may be locked or have corrupt state. Contact Elastic Support.

### 5. Instance Restart Loop Identification
A restart loop in ECH shows as rapid `Restarting` → `Unhealthy` → `Restarting` cycles in the console activity feed.

Common causes of restart loops:
- **OOM on startup**: heap too small for the number of indices/shards (visible as `OutOfMemoryError` in startup logs)
- **Invalid secure settings**: JVM or ES aborts on startup when a keystore entry is invalid
- **Plugin/bundle conflict**: plugin loaded at startup causes exception before ES is ready
- **Too many indices slow startup**: ES takes too long to initialize, times out health check
- **Corrupt cluster state**: ES cannot load cluster state on startup

Diagnosis:
```bash
# Look for loop pattern in activity log: multiple rapid restarts
# Check logs immediately after each restart attempt for startup errors
Deployments → [Deployment] → Logs and metrics → Logs → filter by time of restart
```

### 6. Deployment Unavailable After a Configuration Change
If the deployment became unavailable immediately after a configuration change:
1. Check the plan change activity log for the exact step that failed
2. Identify if the change was a resize, plugin add, secure setting change, or version upgrade
3. If plan failed and rolled back: deployment should return to previous healthy state
4. If rollback also failed: contact Elastic Support

See `plan-change.md` for detailed plan failure analysis.

### 7. Hosted Maintenance-Related Health Messages
ECH performs routine maintenance that can temporarily affect deployment health:

**Expected maintenance behaviors:**
- `Maintenance mode` on an instance: routing deliberately disabled during infrastructure work
- Brief `Restarting` during zone migrations or hardware maintenance
- Unannounced rolling restarts during critical security patches

**How to identify platform maintenance vs. unexpected restart:**
- Maintenance mode set: console shows `Maintenance mode` label on instance
- No customer-initiated plan change: activity log shows no customer action
- Self-heals quickly (minutes, not hours): platform maintenance is usually brief

**If maintenance mode persists > 30 minutes:** Contact Elastic Support — this is abnormal.

### 8. APM / Enterprise Search / Fleet Server Health
Each hosted component has its own health indicator in the console:
```bash
# APM Server — check from client or Dev Tools
curl -s https://<apm-endpoint>:443/ | jq '{ok:.ok, version:.version}'

# Fleet Server
curl -s https://<fleet-endpoint>:443/api/status | jq '.status'

# Enterprise Search
curl -s -u <user>:<pass> https://<ent-search-endpoint>:443/api/ent/v1/internal/health | jq '.'
```
APM/Fleet/Enterprise Search unhealthy = check if ES is healthy first; these components connect to ES and fail if ES is unavailable.

### 9. Service Degradation Triage — Is It the Platform or Workload?
For slow performance or partial service degradation (not full outage):

```bash
# Check thread pool saturation
GET _cat/thread_pool/search,write,management?v&h=name,active,queue,rejected

# Check JVM heap and GC
GET _nodes/stats/jvm | jq '.nodes | to_entries | map({node:.key, heap_pct: (.value.jvm.mem.heap_used_percent), gc_ms: (.value.jvm.gc.collectors.old.collection_time_in_millis)}) | sort_by(.heap_pct) | reverse | .[0:5]'

# Check slow log presence
GET .logs-deprecation.elasticsearch-default/_search?size=5
```

If GC time is high and heap is > 85%: workload-side memory pressure.
If thread pool rejections spike: cluster undersized for the workload, not a platform issue.

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific health signal, component (ES/Kibana/APM/Fleet), and any error messages from the console activity log or instance logs.

## Token Budget
- Cloud console activity log and cluster health API give the fastest signal.
- `grep` for ERROR/FATAL/OutOfMemoryError in instance logs — never read full log file.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
