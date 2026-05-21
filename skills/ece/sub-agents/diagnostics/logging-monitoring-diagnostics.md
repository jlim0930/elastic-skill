---
name: ece-logging-monitoring-diagnostics
description: Diagnoses ECE logging, monitoring, and diagnostic collection issues including need for diagnostics from directors, coordinators, allocators, and proxies; logging-and-metrics cluster unhealthy; platform logs difficult to interpret; UI disk usage discrepancy; correlating container health with deployment symptoms; and determining which host role to inspect first.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE — Logging / Monitoring / Diagnostics Sub-Agent

Scope: Platform diagnostics collection (directors/coordinators/allocators/proxies), logging-and-metrics cluster unhealthy, platform log interpretation, UI metric discrepancies, container health correlation with deployment symptoms, host role inspection priority.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE diagnostics collection"`, `"ECE logging metrics cluster unhealthy"`, `"ECE platform logs"`, `"ECE container logs triage"`, `"ECE disk usage discrepancy"`.

## Diagnostic Steps

### 1. Diagnostic Triage Priority
When investigating an ECE issue, inspect hosts in this order:
```
1. Coordinator / Director hosts → platform state, ZooKeeper, admin console
2. Proxy hosts → deployment endpoint routing
3. Allocator hosts → deployment instance containers
4. System deployments → admin-console-ES, security-cluster, logging-and-metrics
```

### 2. Collect Platform Diagnostics
ECE provides a built-in diagnostic collection tool:
```bash
# Run ECE diagnostics (produces a ZIP bundle)
bash /mnt/data/elastic/scripts/elastic-cloud-enterprise.sh diagnostics \
  --output /tmp/ece-diagnostics.zip \
  --coordinator-host localhost

# For a specific host:
bash /mnt/data/elastic/scripts/elastic-cloud-enterprise.sh diagnostics \
  --host <allocator-ip>
```
The bundle includes Docker container logs, container stats, ECE API state, and host info.

### 3. Platform Logs by Role

**Coordinator / Director:**
```bash
docker logs frc-coordinators-coordinator --since 2h 2>&1 | grep -E "ERROR|FATAL|WARN" | tail -30
docker logs frc-directors-director --since 2h 2>&1 | grep -E "ERROR|WARN|ZooKeeper|quorum" | tail -20
```

**Constructor:**
```bash
docker logs frc-constructors-constructor --since 2h 2>&1 | grep -E "ERROR|WARN|plan|cluster" | tail -20
```

**Proxy:**
```bash
docker logs frc-proxies-proxyv2 --since 2h 2>&1 | grep -E "ERROR|WARN|route|backend" | tail -20
docker logs frc-route-servers-route-server --since 2h 2>&1 | grep -E "ERROR|WARN" | tail -10
```

**Allocator (Runner):**
```bash
docker logs frc-runners-runner --since 2h 2>&1 | grep -E "ERROR|WARN|connect|director" | tail -20
```

### 4. Logging-and-Metrics Cluster Unhealthy
```bash
LOGGING_ID=$(curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch?include_hidden=true" | \
  jq -r '.elasticsearch_clusters[] | select(.cluster_name | test("logging")) | .cluster_id')

curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch/$LOGGING_ID" | \
  jq '{status:.status, shards: .topology.instances | length}'

# Check instances
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch/$LOGGING_ID" | \
  jq '.topology.instances[] | {name:.instance_name, allocator:.allocator_id, running:.service_running}'
```
When logging-and-metrics is down: fall back to direct Docker container logs (above) for platform diagnosis.

### 5. UI Disk Usage Discrepancy
The ECE admin console shows disk usage per deployment. If numbers seem wrong:
```bash
# Actual disk usage per cluster on allocator
docker ps --format "{{.Names}}" | grep -v frc- | while read CONTAINER; do
  SIZE=$(docker inspect $CONTAINER 2>/dev/null | jq -r '.[0].SizeRootFs // 0')
  echo "$CONTAINER: $(( $SIZE / 1024 / 1024 )) MB"
done | sort -t: -k2 -rn | head -10

# OS-level disk usage for ECE data directory
du -sh /mnt/data/elastic/clusters/*/ 2>/dev/null | sort -rh | head -10
```
Discrepancy between UI and disk = UI reads from logging-and-metrics cluster which may be lagging or stale.

### 6. Container Health vs. Deployment Symptoms
To correlate a deployment symptom with container state:
```bash
# Find containers for a deployment
CLUSTER_ID="<cluster-id>"
docker ps --filter "label=com.elastic.cluster.id=$CLUSTER_ID" --format "{{.Names}}\t{{.Status}}"

# Container health check status
docker inspect $(docker ps -q --filter "label=com.elastic.cluster.id=$CLUSTER_ID") \
  | jq '.[] | {name:.Name, health:.State.Health.Status, restarts:.RestartCount}'

# Instance logs
docker logs $(docker ps -q --filter "label=com.elastic.cluster.id=$CLUSTER_ID" | head -1) \
  --tail 50 2>&1 | grep -E "ERROR|FATAL|exception" | tail -20
```

### 7. ECE API State Snapshot
Collect current platform state for analysis:
```bash
# Platform summary
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform" | jq '{version:.version}'

# Allocator summary
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform/infrastructure/allocators" | \
  jq '[.zones[].allocators[] | {id:.allocator_id, connected:.status.connected, used_pct: (100 * .capacity.memory.used / .capacity.memory.total | round)}]'

# Deployment status summary
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch" | \
  jq '[.elasticsearch_clusters[] | {name:.cluster_name, status:.status}] | group_by(.status) | map({status:.[0].status, count:length})'
```

### 8. Time Correlation
When diagnosing an incident, establish the timeline:
```bash
# ECE coordinator logs with timestamps
docker logs frc-coordinators-coordinator --since <incident-time> --until <incident-time+30m> 2>&1 | \
  grep -E "ERROR|WARN" | awk '{print $1, $2, $0}' | head -30

# Container restart times
docker inspect frc-coordinators-coordinator | jq '.[0].State.StartedAt'
```

### 9. Beats / Monitoring Data
ECE uses Metricbeat/Filebeat (via `frc-beats-runner`) to ship monitoring data:
```bash
docker ps --filter "name=frc-beats" --format "{{.Names}}\t{{.Status}}"
docker logs frc-beats-runner-<instance> --tail 20 2>&1 | grep -E "ERROR|WARN|failed" | tail -10
```
If beats runner is stopped: monitoring data gaps in the logging-and-metrics cluster.

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific diagnostic need (which role, what time window, what symptoms).

## Token Budget
- Start with `docker ps` and role-specific log grep.
- ECE diagnostics bundle is comprehensive but slow — use for full incident review, not quick triage.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
