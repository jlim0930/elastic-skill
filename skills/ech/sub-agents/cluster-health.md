---
name: ech-cluster-health
description: Diagnoses Elasticsearch cluster health issues (red/yellow status, heap pressure, shard problems) on Elastic Cloud Hosted deployments.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECH Cluster Health Sub-Agent

Scope: ES cluster red/yellow on ECH, heap/GC pressure, unassigned shards, master instability. ECH-specific context: zone failures, single-AZ vs. multi-AZ, ECH instance sizing.

## Retrieval Protocol
Follow [../../../shared/retrieval-protocol.md](../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECH cluster red unassigned"`, `"Elastic Cloud heap pressure"`, `"ECH single AZ shard replica"`.

## Diagnostic Steps

### 1. Cluster Health
```
GET /_cluster/health?pretty
GET /_cluster/allocation/explain
GET /_cat/nodes?v&h=name,heap.percent,cpu,disk.avail,master
```
Check zone distribution: in a multi-AZ deployment, each zone should have the same number of nodes.

### 2. ECH-Specific Shard Allocation
- Single-AZ deployments: `number_of_replicas: 0` (no replication possible with 1 node).
- Multi-AZ: replicas should be distributed across zones. Check `cluster.routing.allocation.awareness.attributes: zone`.
- If a zone is unreachable, primaries in that zone are unassigned → check Console for zone health.

### 3. Heap and GC on ECH
ECH instance sizes have fixed heap (50% of instance RAM, capped at 31 GB). If heap is consistently >85%:
- Check if autoscaling can increase instance size.
- Check shard count per node (overloading → reduce shard count).
- Check fielddata cache usage.

### 4. Disk on ECH
ECH storage is tied to the deployment size. If at or near capacity:
- Increase storage via deployment plan (triggers a plan change).
- Delete old indices or run ILM to move to colder tiers.

### 5. KCS + Docs Lookup
Execute retrieval protocol now. Query with the specific unassigned reason and ECH context.

## Token Budget
- Filter `_cat/nodes` to heap/disk columns only.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../shared/output-format.md](../../../shared/output-format.md).
Reference thresholds from [../../../shared/thresholds.md](../../../shared/thresholds.md).
