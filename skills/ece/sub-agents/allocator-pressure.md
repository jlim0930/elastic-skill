---
name: ece-allocator-pressure
description: Diagnoses ECE allocator capacity exhaustion, placement constraint failures, and storage pressure causing plan changes to fail or instances to be unmovable.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE Allocator Pressure Sub-Agent

Scope: allocator capacity exhausted, no valid allocator for placement, instance configuration mismatch, storage pressure on allocators.

## Retrieval Protocol
Follow [../../../shared/retrieval-protocol.md](../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE allocator capacity no placement"`, `"ECE allocator disk full"`, `"ECE instance configuration mismatch"`.

## Diagnostic Steps

### 1. Allocator Capacity
Via ECE API or Platform Console:
```
GET /api/v1/platform/infrastructure/allocators
```
Use `jq` to extract per-allocator `available_memory` and `available_storage`:
```bash
jq '.allocators[] | {zone: .zone_id, mem_free: .capacity.memory.total - .capacity.memory.used, disk_free: .capacity.storage.total - .capacity.storage.used}' allocators.json
```
Flag any allocator where memory or storage utilization exceeds 80%.

### 2. Placement Constraints
If a plan change fails with "no allocator available":
- Check if the instance configuration (RAM size, storage type) exists in the target zone.
- Check allocator tags: ECE can restrict instance placement to specific tagged allocators.
- Check if `availability_zone` constraints in the deployment spec match available zones.

### 3. Disk Pressure on Allocators
```bash
df -h /data/elastic   # on each allocator host
df -i /data/elastic   # check inodes
```
ECE containers store data under the allocator's data path. Disk >80% = placement risk; >90% = critical.

### 4. Allocator Connectivity
Allocators must be reachable by the director and proxy:
```bash
nc -zv <director-host> 12443   # director port
```
If an allocator is disconnected from the director, it cannot receive new instances.

### 5. Move Instance
If an instance is stuck on an over-pressured allocator:
- ECE Console → Deployment → Instances → Move instance to a healthy allocator.
- Or via API: `POST /api/v1/clusters/elasticsearch/<cluster-id>/instances/move`.

### 6. KCS + Docs Lookup
Execute retrieval protocol now. Query with the specific constraint type and zone.

## Token Budget
- `jq` filter allocator API response to capacity fields only.
- Never load the full allocator list into context; filter to over-threshold entries.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../shared/output-format.md](../../../shared/output-format.md).
Reference thresholds from [../../../shared/thresholds.md](../../../shared/thresholds.md).
