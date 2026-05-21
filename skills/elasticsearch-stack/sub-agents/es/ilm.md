---
name: es-ilm
description: Diagnoses Elasticsearch ILM policy not attached or not progressing, rollover failures due to alias misconfiguration, phase transition failures, shrink/searchable-snapshot step failures, DSL vs ILM confusion (8.11+), and policy updates not affecting existing indices.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — ILM (Index Lifecycle Management)

**Purpose**: Identify why an index is stuck in an ILM phase or step and prescribe the fix.

## Use When
- Index stuck in a phase for longer than the poll interval (default 10 min)
- `failed_step` visible in ILM explain output
- Rollover not happening despite conditions being met
- Index not migrating to warm/cold/frozen tier

## Do Not Use When
- Shards unassigned blocking ILM tier migration → es/cluster-health first
- Disk full blocking index → es/disk-storage-watermark first

## Inputs Needed
- Index name(s) stuck
- `failed_step` and `step_info.reason` from ILM explain
- ILM policy name and phase configuration
- Whether using data streams or traditional indices

## Diagnostic Logic

### ILM Service Check
- ILM must be `RUNNING` — if `STOPPED`, trigger start via `POST /_ilm/start`
- Poll interval default is 10 minutes — reduce to 1m during troubleshooting, restore after

### Failed Step Classification
| Failed Step | Likely Cause | Fix |
|---|---|---|
| `check-rollover-ready` | Alias not configured or rollover conditions wrong | Fix alias `is_write_index`; verify rollover conditions |
| `rollover` | No write index or multiple write indices on alias | Ensure exactly one `is_write_index: true` |
| `shrink` | Target node lacks space or allocation filter blocks it | Check disk space; check allocation constraints |
| `wait-for-yellow-step` | Cluster health below yellow | Fix cluster health first |
| `wait-for-shard-history-leases-step` | Peer recovery still active | Wait or check recovery progress |
| `searchable-snapshot` | Snapshot repository not configured | Configure repository in ILM policy |
| `freeze` | Deprecated in 8.x | Remove freeze action; use cold tier instead |

### Rollover Prerequisites (Traditional Indices)
- Exactly one index must have `is_write_index: true` on the write alias
- The alias name in `index.lifecycle.rollover_alias` must match exactly (case-sensitive)
- Missing write index → `IllegalArgumentException: no write index is defined for alias`
- Data streams: alias management is automatic — do not set `rollover_alias` manually

### Policy Attachment Verification
- Check `index.lifecycle.name` in index settings — must exactly match an existing policy name
- Check `index.lifecycle.rollover_alias` — must match the write alias name
- Policy changes only take effect at the next step transition, not retroactively mid-step
- Retry a failed step via `POST /<index>/_ilm/retry`

### DSL vs ILM (8.11+)
- Data Stream Lifecycle (DSL) is a simplified alternative to ILM — do NOT apply both
- If DSL is active on a data stream and ILM is also attached → conflicting behavior
- Rollover happening at unexpected times or retention not working → check for DSL conflict
- To use ILM: delete DSL from the data stream; attach ILM via index template instead

### Tier Migration Prerequisites
- `warm` phase requires at least one node with `data_warm` role
- `cold` phase requires `data_cold` role
- `frozen` phase requires `data_frozen` role AND `xpack.searchable.snapshot.shared_cache.size` configured
- If no nodes with the required role exist → ILM waits indefinitely (no error, no progress)
- Verify tier node roles before troubleshooting ILM phase transitions

### Rollover Conditions Not Met
- Check current index size and doc count against policy conditions (`max_age`, `max_primary_shard_size`, `max_docs`)
- If conditions are not met, ILM waits — this is expected behavior
- Force manual rollover bypasses conditions: `POST /<alias>/_rollover`

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for ILM error patterns and `failed_step` entries

## KCS Queries
`"ILM stuck phase elasticsearch failed_step"`, `"rollover failed alias misconfigured write index"`, `"ILM shrink allocation failed"`, `"data stream lifecycle ILM conflict 8.11"`

## Output
Report: index name, failed step, root cause (alias/alias config/tier missing/cluster health), ordered fix steps.
