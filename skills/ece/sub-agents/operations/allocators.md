---
name: ece-allocators
description: Diagnoses ECE allocator issues including allocator disconnected, not used for new deployments, instances stuck on unhealthy allocator, capacity imbalance, allocator host failure, failure to vacate/move nodes, and zone imbalance and affinity issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE — Allocator Sub-Agent

Scope: Allocator disconnected, not used for new deployments, instances stuck on unhealthy allocator, capacity imbalance, allocator host failure affecting deployments, failure to vacate/move nodes, zone imbalance and affinity issues.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE allocator disconnected"`, `"ECE allocator not used deployments"`, `"ECE vacate allocator failed"`, `"ECE capacity imbalance allocators"`, `"ECE allocator zone affinity"`.

## Diagnostic Steps

### 1. Allocator Status Overview
```bash
# List all allocators and their health
curl -s -k -u admin:<pass> https://localhost:12443/api/v1/platform/infrastructure/allocators | \
  jq '[.zones[].allocators[] | {id:.allocator_id, zone:.zone_id, connected:.status.connected, capacity:.capacity.memory.total, used:.capacity.memory.used}]'
```

### 2. Disconnected Allocator
```bash
# Find disconnected allocators
curl -s -k -u admin:<pass> https://localhost:12443/api/v1/platform/infrastructure/allocators | \
  jq '[.zones[].allocators[] | select(.status.connected == false) | {id:.allocator_id, zone:.zone_id}]'

# Check runner container on the allocator host
docker ps --filter "name=frc-runners" --format "{{.Names}}\t{{.Status}}"

# Check runner logs
docker logs frc-runners-runner --tail 50 2>&1 | grep -E "ERROR|WARN|connect|director|ZooKeeper" | tail -20
```
Disconnected allocator = the runner container on that host cannot communicate with the director (ZooKeeper). The allocator still runs existing instances but receives no new work.

### 3. Allocator Not Used for New Deployments
```bash
# Check allocator maintenance mode (maintenance mode = excluded from placement)
curl -s -k -u admin:<pass> https://localhost:12443/api/v1/platform/infrastructure/allocators | \
  jq '[.zones[].allocators[] | select(.status.maintenance_mode == true) | {id:.allocator_id}]'

# Check available capacity
curl -s -k -u admin:<pass> https://localhost:12443/api/v1/platform/infrastructure/allocators | \
  jq '[.zones[].allocators[] | {id:.allocator_id, free_mb: (.capacity.memory.total - .capacity.memory.used)}] | sort_by(.free_mb)'
```
If allocator has capacity but isn't used: check if it has allocation constraints or is in maintenance mode.

### 4. Instances Stuck on Unhealthy Allocator
```bash
# List all instances on a specific allocator
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform/infrastructure/allocators/<allocator-id>/instances" | \
  jq '[.instances[] | {cluster_id:.cluster_id, instance:.instance_name, type:.cluster_type}]'

# Check instance container status on the allocator host
docker ps --filter "label=com.elastic.allocator.id=<allocator-id>" --format "{{.Names}}\t{{.Status}}" | head -20
```

### 5. Vacate an Allocator
Vacating moves all instances off an allocator (before maintenance or decommission):
```bash
# Initiate vacate
curl -s -k -u admin:<pass> -XPOST \
  "https://localhost:12443/api/v1/platform/infrastructure/allocators/<allocator-id>/instances/elasticsearch/moves" \
  -H "Content-Type: application/json" \
  -d '{"allocator_down": false}' | jq '.'

# Monitor vacate progress
curl -s -k -u admin:<pass> \
  "https://localhost:12443/api/v1/platform/infrastructure/allocators/<allocator-id>/instances" | \
  jq '.instances | length'
```
Vacate fails if: target allocators don't have enough capacity, or constraints prevent placement.

### 6. Capacity Imbalance
```bash
# Show memory utilization per allocator
curl -s -k -u admin:<pass> https://localhost:12443/api/v1/platform/infrastructure/allocators | \
  jq '[.zones[].allocators[] | {id:.allocator_id, zone:.zone_id, used_pct: (100 * .capacity.memory.used / .capacity.memory.total | round)}] | sort_by(.used_pct) | reverse'
```
Capacity imbalance: some allocators near full while others are mostly empty. This happens when:
- New allocators were added but existing instances weren't rebalanced
- Zone affinity keeps instances on specific allocators
- Filtered allocators (allocation constraints)

Solution: trigger plan changes on overloaded deployments to allow rebalancing, or manually move instances via the API.

### 7. Zone Imbalance / Affinity Issues
```bash
# Check zone distribution of a deployment's instances
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>" | \
  jq '[.topology.instances[] | {name:.instance_name, zone:.availability_zone, allocator:.allocator_id}]'
```
Instances should be spread across zones for HA. If all instances are in one zone: the deployment is not zone-aware.
Check allocation constraints: `curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>/settings" | jq '.cluster_topology_constraints'`

### 8. Allocator Host Failure Impact
If an allocator host fails:
1. All instances on that allocator become unavailable
2. Multi-node deployments with instances on other allocators continue serving
3. Single-node deployments are fully offline
4. ECE does not automatically re-place instances from a failed allocator

Recovery:
```bash
# After restoring the allocator host, check if instances come back automatically
docker ps --filter "label=com.elastic.allocator.id=<allocator-id>" --format "{{.Names}}\t{{.Status}}"
```
If instances don't recover: trigger a plan change to re-place them on healthy allocators.

### 9. Allocation Constraints
```bash
# Check allocator tags/attributes
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform/infrastructure/allocators/<allocator-id>" | \
  jq '{tags:.metadata.tags, zone:.zone_id}'

# Check deployment's instance configuration for constraints
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>" | \
  jq '.plan_info.current.plan.cluster_topology[].instance_configuration_id'
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the allocator error (disconnected, capacity issue, vacate failure) and ECE version.

## Token Budget
- Allocator status API gives instant capacity and connectivity picture.
- `docker ps` on allocator host to verify instances running.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
