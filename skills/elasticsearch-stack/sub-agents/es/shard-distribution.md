---
name: es-shard-distribution
description: Diagnoses Elasticsearch oversharding, undersharding, uneven shard allocation causing hot nodes, slow shard recovery, rebalancing taking too long, and tier allocation mistakes across hot/warm/cold/frozen tiers.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — Shard Distribution

**Purpose**: Diagnose shard count problems, node imbalance, recovery issues, and tier allocation misrouting.

## Use When
- Cluster is oversharded (too many small shards)
- One node is hot while others are idle
- Shard recovery is taking too long
- Index not moving to expected tier (warm/cold/frozen)

## Do Not Use When
- Shards are unassigned → es/cluster-health
- Indexing performance is slow but shard distribution is even → es/indexing-performance

## Inputs Needed
- Total shard count and JVM heap total across cluster
- Per-node shard counts
- Shard sizes (store) per shard
- Current tier assignments (node roles)

## Diagnostic Logic

### Oversharding Check
- Target: ≤ 20 shards per GB of JVM heap (cluster-wide)
- > 50 shards/GB = critical oversharding
- Symptoms: high heap despite moderate data, slow cluster state updates, GC pressure with each rollover
- Optimal shard size: 10–50 GB per shard
- Fix: increase ILM rollover `max_primary_shard_size`; shrink oversized indices

### Undersharding Check
- Shard > 65 GB = recovery/search performance risk
- Signal: search latency high, low parallelism (all load on one shard)
- Fix: reindex with more primary shards (cannot change after creation)

### Node Imbalance / Hot Nodes
- One node has disproportionate shard count or CPU
- Causes: allocation filters pinning shards; zone awareness with unequal node counts; newly added node still rebalancing
- Check: `index.routing.allocation.require.*` filters on affected indices
- Check: `cluster.routing.allocation.enable` is set to `all` (not `none` or `primaries`)
- Force retry: `_cluster/reroute?retry_failed=true`

### Shard Recovery Speed
- Large shards (>20 GB) take long to recover
- Default recovery throttle: 40 MB/s — increase during maintenance if disk I/O allows
- Settings: `indices.recovery.max_bytes_per_sec`, `cluster.routing.allocation.node_concurrent_recoveries`
- Restore to defaults after recovery completes

### Tier Allocation Mistakes
| Issue | Check |
|---|---|
| Index not moving to warm | ILM policy missing `migrate` action; wrong `_tier_preference` |
| Index stuck on warm | `index.routing.allocation.require.*` conflict with tier |
| Node not recognized as tier | Node missing correct `node.roles` (e.g., `data_warm`) |
| All shards on one tier | Tier roles not configured; all nodes using `data` role |

Check current tier assignment via `index.routing.allocation.include._tier_preference` setting on the index.

## Shared Skills
→ [performance_triage](../../../../shared/performance_triage.md) — if hot node is causing performance impact
→ [error_pattern_matching](../../../../shared/error_pattern_matching.md) — for allocation failure reasons

## KCS Queries
`"oversharding elasticsearch too many shards"`, `"shard imbalance hot node"`, `"shard recovery slow large"`, `"tier allocation hot warm cold"`

## Output
Report: shards/GB ratio, node balance, oversize/undersize shards, tier issue if any, recommended actions.
