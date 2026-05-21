---
name: ech-snapshot-restore
description: Diagnoses ECH snapshot and restore issues including snapshot failures, restore failures, restore conflicts with existing resources, hosted snapshot repository behavior, searchable snapshot expectations, slow or partial restore concerns, recovery after a failed restore, and SLM policy issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECH — Snapshot & Restore Sub-Agent

Scope: Snapshot failures, restore failures, restore conflicts with existing resources, hosted snapshot repository behavior, searchable snapshot expectations, slow/partial restore, recovery after a failed restore, SLM policies.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECH snapshot failure"`, `"Elastic Cloud restore failed"`, `"ECH snapshot repository"`, `"Elastic Cloud searchable snapshot"`, `"ECH restore conflict"`, `"Elastic Cloud slow restore"`, `"ECH SLM policy"`.

## Diagnostic Steps

### 1. ECH Managed Snapshot Repository
ECH provides a **managed snapshot repository** automatically for every deployment:
- Repository name: `found-snapshots`
- Snapshots taken automatically every 30 minutes (default)
- Retained for 12 snapshots (configurable in ECH console)
- Stored in cloud provider object storage (AWS S3 / GCP GCS / Azure Blob) managed by Elastic

```bash
# Check managed repository status
GET _snapshot/found-snapshots

# List recent snapshots (latest 5)
GET _snapshot/found-snapshots/_all?verbose=false | jq '.snapshots | sort_by(.start_time) | reverse | .[:5] | map({id:.snapshot, state:.state, start:.start_time, indices:.indices | length})'
```

### 2. Snapshot Failure Diagnosis
```bash
# Get details on a failed snapshot
GET _snapshot/found-snapshots/<snapshot-name>

# Check in-progress snapshot status
GET _snapshot/_status

# Look for snapshot failures in the last 10 snapshots
GET _snapshot/found-snapshots/_all?verbose=true | jq '.snapshots | sort_by(.start_time) | reverse | .[:10] | map(select(.state != "SUCCESS")) | map({id:.snapshot, state:.state, failures:.failures[0:3]})'
```

Common snapshot failure causes:
| Cause | Symptom | Fix |
|---|---|---|
| Cluster is red | Snapshot fails immediately — primary shard unavailable | Fix cluster health first |
| Concurrent snapshot | `ConcurrentSnapshotExecutionException` | Wait for in-progress snapshot to complete |
| Repository quota exceeded | Storage quota on object store | Delete old snapshots or increase quota |
| Node failure during snapshot | `PARTIAL` state | Retry snapshot after node recovers |
| Repository inaccessible | `RepositoryException` | Check credentials and network to object store |

### 3. Custom Snapshot Repository Setup and Verification
If using a customer-managed repository (S3, GCS, Azure Blob):
```bash
# Verify repository connectivity and permissions
POST _snapshot/<repo-name>/_verify

# Check repository configuration
GET _snapshot/<repo-name>
```

Custom repository failure causes:
- Wrong bucket name, region, or base path
- Insufficient IAM/service account permissions (need: `GetObject`, `PutObject`, `DeleteObject`, `ListBucket`)
- Base path within the bucket does not exist or has wrong ownership
- Network access to the object storage endpoint is blocked

In ECH, repository credentials are stored as **secure settings** (keystore):
```bash
# Verify secure settings include repository credentials
GET _nodes/settings | jq '.nodes | to_entries[0].value.settings | to_entries | map(select(.key | test("s3|gcs|azure"))) | map(.key)'
```

### 4. Restore Failure — Conflict with Existing Resources
**Index already exists:**
```bash
# Option 1: Close the existing index before restore
POST /<index-name>/_close

# Then restore
POST _snapshot/found-snapshots/<snapshot-name>/_restore
{"indices": ["<index-name>"]}

# Option 2: Restore with rename to avoid conflict
POST _snapshot/found-snapshots/<snapshot-name>/_restore
{
  "indices": ["<index-name>"],
  "rename_pattern": "(.+)",
  "rename_replacement": "restored-$1"
}
```

**Data stream already exists:**
- Cannot restore a data stream if the same data stream exists — must delete it first
```bash
DELETE _data_stream/<data-stream-name>
POST _snapshot/found-snapshots/<snapshot-name>/_restore
{"indices": ["<data-stream-name>"]}
```

**ILM policy conflict:** Restored index with an ILM policy that references a missing rollover alias — set `index.lifecycle.name` to null after restore if needed.

### 5. Restore Failure — Snapshot Issues
```bash
# Check snapshot state
GET _snapshot/found-snapshots/<snapshot-name> | jq '.snapshots[0] | {state:.state, failures:.failures, shards:.shards}'
```

| Snapshot state | Meaning | Action |
|---|---|---|
| `SUCCESS` | Complete — safe to restore | Proceed with restore |
| `PARTIAL` | Some shards missing — partial restore possible | Restore will succeed but some data lost; find earlier SUCCESS snapshot |
| `FAILED` | Corrupt or incomplete — cannot restore | Use the most recent SUCCESS snapshot before this one |
| `IN_PROGRESS` | Currently running | Wait for completion before restoring |

To find the most recent successful snapshot:
```bash
GET _snapshot/found-snapshots/_all?verbose=false | jq '[.snapshots[] | select(.state == "SUCCESS")] | sort_by(.start_time) | reverse | .[0] | {id:.snapshot, time:.start_time}'
```

### 6. Searchable Snapshots in ECH
Searchable snapshots allow querying snapshot data directly without full restore:
```bash
# Mount a searchable snapshot index
POST _snapshot/found-snapshots/<snapshot-name>/_mount
{
  "index": "<index-name>",
  "renamed_index": "<mounted-index-name>",
  "storage": "shared_cache"
}
```

Storage options:
| Storage type | Behavior | Use case |
|---|---|---|
| `shared_cache` | Data fetched from repository on-demand, shared cache between indices | Frozen tier — infrequent queries, lowest cost |
| `full_copy` | Full local copy cached on data nodes | Cold tier — frequent but slower queries |

**Performance expectations for searchable snapshots:**
- Much slower than regular hot indices for non-cached queries (repository latency)
- First-access queries are slower; subsequent queries use local cache
- Not suitable for high-throughput or latency-sensitive workloads
- Best for long-term retention queries on historical data

### 7. Slow Restore
Large index restores are slow because:
- Data transfers from cloud object storage to Elasticsearch data nodes
- Parallelism is limited to the number of primary shards (each shard restores on one node)
- Bandwidth is bounded by the object storage endpoint and the network

Estimate restore time:
```
Approximate: index_size_GB / (number_of_primary_shards × ~50 MB/s per shard)
Example: 1 TB index with 10 shards → ~200s per shard → ~3-4 minutes (shards restore in parallel)
```

Monitor restore progress:
```bash
GET _recovery?active_only=true | jq '.[] | to_entries | map({index:.key, type:.value.shards[0].type, percent:.value.shards[0].index.percent}) | select(.[].type == "SNAPSHOT")'
```

### 8. Recovery After a Failed Restore
If restore failed partway and the index is in a bad state:
```bash
# Check cluster health and shard state
GET _cluster/health
GET _cat/shards?v&h=index,shard,prirep,state,unassigned.reason&s=state:desc | head -20
```

If partially restored shards are stuck in UNASSIGNED:
```bash
# Delete the partial index and retry
DELETE /<partially-restored-index>

# Then restore again from a clean snapshot
POST _snapshot/found-snapshots/<snapshot-name>/_restore
{"indices": ["<index-name>"]}
```

Do not leave partially restored indices in place — they consume disk space and may block new shard allocation.

### 9. Snapshot Lifecycle Management (SLM)
```bash
# Check SLM policies
GET _slm/policy

# Check SLM execution history
GET _slm/stats | jq '{policies:.policy_count, snapshots_taken:.snapshots_taken, snapshots_failed:.snapshots_failed, retention_runs:.retention_runs}'

# Manually execute a snapshot
POST _slm/policy/<policy-name>/_execute

# Run retention manually
POST _slm/_execute_retention
```

If SLM is not running: check that no cluster-level settings block SLM scheduling.

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific snapshot/restore error, repository type (managed `found-snapshots` or custom), and whether the cluster is healthy.

## Token Budget
- Check snapshot state (`GET _snapshot/<repo>/<name>`) before any log analysis.
- `_recovery?active_only=true` for restore progress — never read full recovery stats.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
