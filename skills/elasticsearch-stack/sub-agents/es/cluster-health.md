---
name: es-cluster-health
description: Diagnoses Elasticsearch cluster red/yellow status, unassigned shards, master election failures, node flapping, split-brain, quorum issues, and cluster blocks including flood-stage read-only and metadata blocks.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — Cluster Health

**Purpose**: Isolate why the cluster is red/yellow, identify the root cause of unassigned shards or master instability, and restore cluster availability.

## Use When
- Cluster status is red or yellow
- Shards are unassigned
- Master election is failing or unstable
- Nodes are joining/leaving repeatedly
- Cluster blocks are preventing writes

## Do Not Use When
- Slow searches without health impact → es/search-performance
- Disk full but health not yet red → es/disk-storage-watermark

## Inputs Needed
- Cluster health status and unassigned shard count
- `unassigned.reason` from cat/shards
- Recent log lines (node joins, master changes, exceptions)
- Recent changes (upgrade, restart, node removal)

## Diagnostic Logic

### Status → Priority
- `red` = primary shard(s) unassigned → data unavailable → urgent
- `yellow` = only replicas missing → reads OK, durability reduced → investigate but not emergency
- `green` with user complaints → check specific index, not global health

### Unassigned Shards
Map `unassigned.reason` to action:
| Reason | Action |
|---|---|
| `NODE_LEFT` | Wait for node to rejoin or fix the missing node |
| `ALLOCATION_FAILED` | Run retry_failed reroute; check allocation explain |
| `INDEX_CREATED` | Check replica count vs available nodes |
| `CLUSTER_RECOVERED` | Check disk watermarks post-restart |
| `FORCED_EMPTY_PRIMARY` | Data loss risk — investigate history |

Use `_cluster/allocation/explain` to get the specific reason when `reason` alone is unclear.

### Master Stability
- Repeated master changes in logs = network partition, GC pause, or quorum loss
- Check `discovery.seed_hosts` includes all master-eligible nodes
- 7.x+: needs majority of master-eligible nodes (3-node = needs 2; 5-node = needs 3)
- Pre-7.x: `minimum_master_nodes` = floor(eligible/2) + 1
- Odd number of master-eligible nodes required (3 or 5 for production)

### Node Flapping
Repeated join/leave cycles indicate:
- GC pauses causing heartbeat timeout → check heap %
- Network packet loss → see [shared/network_connectivity_checks](../../../../shared/network_connectivity_checks.md)
- Clock skew between nodes

### Cluster Blocks
| Block | Cause | Resolution |
|---|---|---|
| `read_only_allow_delete` on index | Disk flood-stage (>95%) | Free disk first, then remove block |
| `cluster.blocks.read_only` | Cluster-level disk threshold | Remove block after fixing disk |
| `metadata` block | Write blocked on master | Check disk on master node |

Always fix disk before removing a block — removing the block without fixing disk re-triggers it immediately.

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for `node.*joined`, `node.*left`, `master node changed`
→ [network_connectivity_checks](../../../../shared/network_connectivity_checks.md) — if transport port 9300 is suspected blocked
→ [error_pattern_matching](../../../../shared/error_pattern_matching.md) — classify error from logs

## KCS Queries
`"cluster red unassigned primary"`, `"master not discovered elasticsearch"`, `"node left cluster flapping"`, `"cluster block read only flood stage"`

## Output
Report: status, unassigned count + reason, root cause (node loss / disk / allocation failure / master instability), and next action.
