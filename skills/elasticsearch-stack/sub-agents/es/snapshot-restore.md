---
name: es-snapshot-restore
description: Diagnoses Elasticsearch snapshot repository registration failures and verification errors, stuck or incomplete snapshots, restore conflicts with existing indices, cloud credential issues, SLM policy failures, and searchable snapshot problems.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — Snapshot & Restore

**Purpose**: Identify why a snapshot failed, a repository is broken, or a restore is blocked, and prescribe the fix.

## Use When
- Snapshot stuck `IN_PROGRESS` or ended `PARTIAL`/`FAILED`
- Repository verification failing
- Restore blocked by existing index conflict
- SLM policy not executing or showing failures
- Searchable snapshot not serving data from frozen tier

## Do Not Use When
- Disk full preventing snapshot → es/disk-storage-watermark first
- Cluster unhealthy preventing snapshot operations → es/cluster-health first

## Inputs Needed
- Repository type (s3, gcs, azure, fs)
- Snapshot state (IN_PROGRESS, PARTIAL, FAILED, SUCCESS)
- Exact error message from `_snapshot/<repo>/_status` or logs
- Whether using SLM or manual snapshots

## Diagnostic Logic

### Repository Verification
- Repository verify failure = credentials, permissions, or network connectivity to storage backend
- Run `_snapshot/<repo>/_verify` — each node tests access independently
- If some nodes pass and others fail → per-node credential or network issue

### Repository Auth Errors by Type
| Type | Common Error | Check |
|---|---|---|
| `s3` | `AccessDenied` or `InvalidClientTokenId` | IAM role or keystore credentials; bucket policy |
| `gcs` | `403 Forbidden` | Service account permissions; bucket ACL |
| `azure` | `AuthenticationFailed` | SAS token expired; account key in keystore |
| `fs` | `permission denied` | Shared path mounted on all nodes; correct ownership |

### Snapshot State Analysis
| State | Meaning | Action |
|---|---|---|
| `IN_PROGRESS` | Running | Monitor — check if single shard is stuck |
| `SUCCESS` | Completed | Verify shard count matches expected |
| `PARTIAL` | Some shards not captured | Inspect `failures[]` array for failed shards |
| `FAILED` | Snapshot failed | Read `failure` field for reason |

- `IN_PROGRESS` > 1 hour: identify which shard is not in DONE stage
- `PARTIAL`: shard failure during snapshot → target shard's node was unavailable or shard had errors

### Restore Conflicts
- `index already exists` → choose one approach:
  1. Rename on restore (recommended): use `rename_pattern` / `rename_replacement`
  2. Delete existing index first (data loss risk)
  3. Close existing → restore → reopen
- Cannot restore a data stream if backing indices exist — delete the data stream first
- `include_global_state: false` prevents restoring cluster-wide settings (safer for partial restores)

### Cloud Credential Rotation
- Credentials stored in Elasticsearch keystore (not elasticsearch.yml)
- Update keystore values on each node, then trigger reload via `_nodes/reload_secure_settings`
- No restart required after keystore reload
- IAM role-based access (AWS): no static credentials if ES runs on EC2/EKS with instance role

### Required S3 Permissions
`s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket`, `s3:GetBucketLocation`

### SLM Failures
- Check `last_failure_info` in `_slm/policy/<name>` for error details
- SLM requires a master node and a healthy repository to execute
- Execute manually to test: `POST /_slm/policy/<name>/_execute`
- Trigger retention manually: `POST /_slm/_execute_retention`

### Searchable Snapshots (Frozen Tier)
- Requires `xpack.searchable.snapshot.shared_cache.size` configured on frozen tier nodes
- Default value is 0 — searchable snapshots do not work without this setting
- Minimum: 10% of disk or 100 GB (whichever is smaller) as a starting point
- Cache miss = reads from object storage; cache hit = reads from local disk

## Shared Skills
→ [snapshot_triage](../../../../shared/snapshot_triage.md) — repo types, snapshot states, common fix table
→ [log_filtering](../../../../shared/log_filtering.md) — filter for RepositoryException, AccessDenied, snapshot error patterns

## KCS Queries
`"snapshot repository failed verify elasticsearch"`, `"snapshot stuck partial incomplete"`, `"restore index already exists elasticsearch"`, `"SLM policy failure elasticsearch"`, `"searchable snapshot frozen cache"`

## Output
Report: repository health, snapshot state, root cause (credentials/permissions/conflict/cache), fix steps.
