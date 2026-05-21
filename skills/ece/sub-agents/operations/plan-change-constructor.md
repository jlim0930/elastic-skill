---
name: ece-plan-change-constructor
description: Diagnoses ECE plan change and constructor issues including plan changes fail, stuck pending, constructor cannot complete deployment changes, restart/reconfiguration loops during plan application, invalid settings causing plan failure, rolling vs non-rolling plan confusion, and maintenance operations blocked by failed plan orchestration.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE — Plan Change / Constructor Sub-Agent

Scope: Plan changes fail, stuck pending, constructor cannot complete deployment changes, restart loops during plan application, invalid settings causing plan failure, rolling vs non-rolling plan, maintenance operations blocked.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE plan change failed"`, `"ECE plan stuck pending"`, `"ECE constructor blocked"`, `"ECE plan change rollback"`, `"ECE invalid settings plan failure"`.

## Diagnostic Steps

### 1. Check Current Plan Status
```bash
# Get plan info for a deployment
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>" | \
  jq '{
    status: .status,
    pending_plan: .plan_info.pending.plan_attempt_id,
    current_plan: .plan_info.current.plan_attempt_id,
    last_error: .plan_info.history[-1].plan_attempt_log[-1]
  }'
```

### 2. Plan History — Find the Failure
```bash
# Full plan history with error details
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>" | \
  jq '.plan_info.history[-3:] | reverse | .[] | {
    id: .plan_attempt_id,
    healthy: .healthy,
    status: .attempt_end_time,
    last_log: .plan_attempt_log[-3:] | map({step:.step_type, status:.status, info:.info_log[-1]})
  }'
```

### 3. Common Plan Failure Types
| Failure | Cause | Signal in plan log |
|---|---|---|
| Invalid configuration | Bad setting, unsupported value | `configuration_validation_failure` |
| Instance startup failure | OOM, bad plugin, bad config | `instance_healthy_check_failure` |
| No allocator capacity | Insufficient memory on allocators | `no_allocator_found` |
| Rolling restart timeout | Node takes too long to restart | `instance_healthy_timeout` |
| Snapshot pre-flight failure | Snapshot fails before plan change | `snapshot_failure` |

### 4. Plan Stuck Pending
```bash
# Check if constructor is healthy
docker ps --filter "name=frc-constructors" --format "{{.Names}}\t{{.Status}}"
docker logs frc-constructors-constructor --tail 50 2>&1 | grep -E "ERROR|WARN|stuck|lock|blocked" | tail -20

# Check pending plan started time (is it actually progressing?)
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>" | \
  jq '.plan_info.pending | {id:.plan_attempt_id, started:.attempt_start_time}'
```
If pending plan has been running > 30 minutes with no progress: constructor may be stuck or ZooKeeper is having issues.

### 5. Cancel a Stuck Plan
```bash
# Cancel a pending plan change
curl -s -k -u admin:<pass> -XDELETE \
  "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>/plan/pending" | jq '.'
```
After canceling: the deployment returns to its last known good configuration.

### 6. Instance Startup Failure Loop
If the plan change is applying but the same instance keeps failing to start:
```bash
# Check the instance container on the allocator
docker ps --filter "label=com.elastic.cluster.id=<cluster-id>" --format "{{.Names}}\t{{.Status}}"

# Check instance logs
docker logs <instance-container> --tail 100 2>&1 | grep -E "ERROR|FATAL|exception|OOM" | tail -20
```
Common startup failures:
- OOM → heap too large for the allocated RAM
- Bad plugin → plugin fails to load on startup
- Invalid keystore entry → configuration setting referenced but not in keystore

### 7. No Allocator Capacity
```bash
# Check available capacity
curl -s -k -u admin:<pass> https://localhost:12443/api/v1/platform/infrastructure/allocators | \
  jq '[.zones[].allocators[] | {id:.allocator_id, free_mb: (.capacity.memory.total - .capacity.memory.used)}] | sort_by(.free_mb) | reverse | .[0]'
```
If no allocator has sufficient free memory: the plan change cannot place the new/resized instance.
Solutions: add more allocators, reduce the instance size, or remove unused deployments.

### 8. Rolling vs. Non-Rolling Plan
A rolling restart updates instances one at a time (less disruptive).
A non-rolling restart updates all instances simultaneously (faster but causes downtime):
```bash
# Force non-rolling plan (use for maintenance only)
curl -s -k -u admin:<pass> -XPOST \
  "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>/_restart" \
  -H "Content-Type: application/json" \
  -d '{"rolling": false}' | jq '.'
```

### 9. Constructor Logs
```bash
docker logs frc-constructors-constructor --tail 200 2>&1 | \
  grep -E "ERROR|WARN|plan.*<cluster-id>|failed|exception" | tail -30
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific plan step that failed and the error message from the plan log.

## Token Budget
- Plan history API (last 3 attempts) gives the failure step immediately.
- Check constructor container before investigating plan log in depth.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
