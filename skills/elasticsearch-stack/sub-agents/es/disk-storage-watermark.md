---
name: es-disk-storage-watermark
description: Diagnoses Elasticsearch high disk usage, flood-stage watermark triggering read-only indices, shard allocation blocked by disk thresholds, slow storage causing merge/recovery delays, inode exhaustion, and NAS/network-attached storage issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — Disk / Storage / Watermark

**Purpose**: Identify disk pressure, restore writability, and prevent recurrence.

## Use When
- Indices become read-only unexpectedly
- Shard allocation failing with disk-related reason
- `ClusterBlockException` with `read-only` message
- Disk usage approaching or exceeding watermarks

## Do Not Use When
- I/O is slow but disk has plenty of space → es/cpu-threadpool-os (merge/I/O)
- Shards unassigned for non-disk reasons → es/cluster-health

## Inputs Needed
- Disk usage % per node
- Current watermark settings (or confirm defaults)
- Which indices are read-only
- Largest indices by size

## Diagnostic Logic

### Watermark Thresholds (defaults)
| Watermark | Default | Effect |
|---|---|---|
| `low` | 85% | No new shards allocated to this node |
| `high` | 90% | Shards moved away from this node |
| `flood_stage` | 95% | All indices on node set to read-only |

### Resolution Order
**Critical rule**: always free disk FIRST, then clear the block. Clearing without freeing re-triggers immediately.

1. Identify largest indices and candidates for deletion, ILM transition, or tiering
2. Delete old indices or move to cold/frozen tier
3. Verify disk % is below `high` watermark (90% default)
4. Clear `read_only_allow_delete` block on affected indices
5. Clear cluster-level `read_only` block if set

### Finding Disk Space
- Check largest indices sorted by store size
- High replica count on large indices → temporarily reduce replicas
- Indices eligible for ILM transition → verify ILM policy is running
- Closed indices still consume disk → open them or delete if no longer needed

### Forcemerge Warning
Forcemerge temporarily **doubles** disk usage during operation (rewrites all segments).
- Never run forcemerge when disk is already near a watermark
- Only forcemerge read-only (non-active) indices
- After forcemerge completes, disk returns to single-segment size

### Temporary Watermark Adjustment
Adjust watermarks temporarily only as emergency measure while freeing disk:
- Lower limits → set high watermark to `92%`, flood_stage to `97%`
- Restore to defaults immediately after disk is freed
- Do not leave custom watermarks permanently (masks future problems)

### Inode Exhaustion
- Inodes exhaust independently from bytes
- Many small indices + many segments = high inode usage
- Fix: reduce shard/segment count (forcemerge, shard shrink)

### NAS / Network Storage
- NAS is NOT recommended for hot/warm tier (high I/O latency = merge/flush timeouts)
- NAS IS appropriate for: frozen tier with searchable snapshots, snapshot repositories
- If NAS on hot tier: recommend migration to local SSD

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for `flood stage`, `read_only`, `watermark`

## KCS Queries
`"flood stage watermark read only index elasticsearch"`, `"disk high watermark shard allocation blocked"`, `"inode exhaustion elasticsearch"`

## Output
Report: disk % per node, which watermark triggered, which indices are blocked, and ordered resolution steps.
