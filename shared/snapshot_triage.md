# Snapshot Triage

**Purpose**: Diagnose snapshot and restore failures across all repository types.

## Repository Types and Common Auth Errors
| Type | Auth Error Signal |
|---|---|
| S3 | `AccessDenied`, `NoCredentialProviders`, `InvalidSignatureException` |
| GCS | `401 Unauthorized`, `403 Forbidden`, service account key missing |
| Azure | `AuthenticationFailed`, `BlobNotFound` |
| Shared filesystem | Mount not present, permission denied on path |
| Read-only URL | URL not reachable, 404 |

## Step 1 — Check Repository Status
- Is the repository registered and verified?
- Verify the repo (triggers a test write) — if it fails, credentials or connectivity is wrong
- For cloud repos: confirm credentials are set in the ES keystore (not in plaintext yml)

## Step 2 — Check Snapshot State
| State | Meaning |
|---|---|
| `IN_PROGRESS` | Still running |
| `SUCCESS` | Completed fully |
| `PARTIAL` | Some shards failed — check `failures[]` |
| `FAILED` | Snapshot did not complete — check `reason` |

## Step 3 — Snapshot Stuck or Slow
- Identify which shards are still in progress
- Check if the shard's node has network/disk issues
- Large shards or slow network → expected long duration
- Stuck at 0% progress → likely a node or connectivity issue blocking the shard

## Step 4 — Restore Conflicts
- Index already exists with incompatible settings → close or delete before restore
- Restore to different cluster version → check version compatibility (restore from older to newer only)
- Not enough shards/nodes for restored replica count → restore with `index.number_of_replicas: 0` then increase

## Step 5 — SLM (Snapshot Lifecycle Management) Issues
- Policy not running → check task manager health (Kibana SLM runs on task manager)
- Retention not deleting → check minimum count settings and policy schedule
- Policy error → check last execution failure reason

## Step 6 — Searchable Snapshots
- Requires Platinum license
- Cache tier (warm): partial mount; some reads still hit remote storage
- Frozen tier: full mount; all reads hit remote storage
- Performance depends on remote storage latency and cache hit rate

## Common Fixes
| Issue | Fix |
|---|---|
| S3 `AccessDenied` | Rotate credentials via keystore; don't store in yml |
| Snapshot `PARTIAL` | Check which shards failed; fix node health; retry |
| GCS auth | Verify service account has Storage Object Admin role |
| Restore "index exists" | Close index first or use `rename_pattern` |
| SLM not executing | Check task manager health; ensure `.slm-history-*` index accessible |
