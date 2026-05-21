---
name: ece-performance-capacity
description: Diagnoses ECE platform and deployment performance and capacity issues including platform slow under load, allocator resource exhaustion, oversharding across hosted deployments, hot allocators with uneven placement, memory pressure on platform or deployments, disk pressure, capacity planning for ECE roles, and constructor/proxy bottlenecks at scale.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE — Performance & Capacity Sub-Agent

Scope: Platform slow under load, allocator resource exhaustion, oversharding across hosted deployments, hot allocators, memory/disk pressure, capacity planning for ECE roles, constructor/proxy bottlenecks at scale.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE allocator resource exhaustion"`, `"ECE platform slow under load"`, `"ECE oversharding"`, `"ECE hot allocator"`, `"ECE capacity planning"`.

## Diagnostic Steps

### 1. Allocator Capacity Overview
```bash
# Capacity utilization per allocator
curl -s -k -u admin:<pass> https://localhost:12443/api/v1/platform/infrastructure/allocators | \
  jq '[.zones[].allocators[] | {
    id: .allocator_id,
    zone: .zone_id,
    total_gb: (.capacity.memory.total / 1024),
    used_gb: (.capacity.memory.used / 1024),
    used_pct: (100 * .capacity.memory.used / .capacity.memory.total | round),
    instances: (.instances | length)
  }] | sort_by(.used_pct) | reverse'
```
Rule of thumb: allocator memory utilization > 80% = pressure; > 90% = at capacity.

### 2. Host Resource Usage on Allocators
```bash
# CPU, memory, load on the allocator host
top -b -n1 | head -20
free -h
df -h /mnt/data

# Check if Docker is consuming excessive resources
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | sort -k2 -rn | head -15
```

### 3. Hot Allocators — Uneven Placement
```bash
# Identify which allocators have the most instances
curl -s -k -u admin:<pass> https://localhost:12443/api/v1/platform/infrastructure/allocators | \
  jq '[.zones[].allocators[] | {id:.allocator_id, instance_count: (.instances | length), used_pct: (100 * .capacity.memory.used / .capacity.memory.total | round)}] | sort_by(.used_pct) | reverse'

# Find large deployments that may be causing hot spots
curl -s -k -u admin:<pass> https://localhost:12443/api/v1/clusters/elasticsearch | \
  jq '[.elasticsearch_clusters[] | {name:.cluster_name, id:.cluster_id, size_mb: (.plan_info.current.plan.cluster_topology | map(.memory_per_node) | add // 0)}] | sort_by(.size_mb) | reverse | .[0:10]'
```

### 4. Disk Pressure on Allocators
```bash
# Check disk usage for ECE data directory
df -h /mnt/data

# Check disk usage per container (top consumers)
du -sh /mnt/data/elastic/clusters/*/ 2>/dev/null | sort -rh | head -10

# ES-level disk watermarks
curl -s -k -u admin:<pass> "https://localhost:9243/<cluster-endpoint>/_cat/allocation?v&h=node,disk.used,disk.avail,disk.total,disk.percent&s=disk.percent:desc" | head -10
```
ECE Elasticsearch disk watermark defaults: 85% high, 90% flood.

### 5. Oversharding Across Hosted Deployments
Oversharding causes excessive JVM heap pressure on allocators:
```bash
# Check shard count for all deployments
for CLUSTER_ID in $(curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch" | jq -r '.elasticsearch_clusters[].cluster_id'); do
  HEALTH=$(curl -s -k -u admin:<pass> "https://localhost:9243/$CLUSTER_ID/_cluster/health" 2>/dev/null)
  SHARDS=$(echo $HEALTH | jq '.active_shards // 0')
  echo "$CLUSTER_ID: $SHARDS shards"
done | sort -t: -k2 -rn | head -10
```
Deployments with > 20 shards per GB of heap = oversharded.

### 6. Platform Service Resource Usage
```bash
# Check ECE platform container resource usage
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" \
  | grep -E "frc-coordinators|frc-directors|frc-proxies|frc-constructors|frc-zookeeper" | sort -k3 -rn
```

### 7. Constructor Bottlenecks at Scale
If many plan changes are queued and progress is slow:
```bash
# Check how many plans are pending
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch" | \
  jq '[.elasticsearch_clusters[] | select(.plan_info.pending != null) | .cluster_id] | length'

docker logs frc-constructors-constructor --tail 50 2>&1 | grep -E "queue|backlog|pending|concurrent" | tail -10
```

### 8. Proxy Bottlenecks at Scale
```bash
# Check proxy connection stats
docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep proxy

# Active connections to proxy
ss -tn state established sport = :9243 | wc -l
ss -tn state established sport = :9200 | wc -l
```
Proxy CPU > 80% or high connection count = proxy bottleneck. Add more proxy hosts.

### 9. Capacity Planning for ECE Roles
ECE role sizing guidelines:
| Role | Min RAM | vCPU | Storage |
|---|---|---|---|
| Director (coordinator) | 8 GB | 4 | 50 GB (OS + ECE) |
| Proxy | 4 GB | 4 | 20 GB |
| Allocator | 32+ GB | 8+ | 2× hosted RAM + 20% overhead |

Allocator storage: each GB of hosted deployment RAM requires ~30 GB of disk (typical log/metrics ratio).

### 10. KCS + Docs Lookup
Execute retrieval protocol with the observed resource metric (CPU%, memory%, disk%), the role (allocator/proxy/coordinator), and the ECE version.

## Token Budget
- Allocator capacity API gives fleet-wide picture in one call.
- `docker stats` for platform container resource baseline.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
