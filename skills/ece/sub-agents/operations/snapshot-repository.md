---
name: ece-snapshot-repository
description: Diagnoses ECE snapshot and repository issues including snapshots stopped running, snapshot repository misconfiguration, restore failures in ECE-managed deployments, repository credential issues, platform snapshot expectations versus deployment snapshot behavior, and snapshot failures during platform instability.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE — Snapshot & Repository Sub-Agent

Scope: Snapshots stopped running, snapshot repository misconfiguration, restore failures in ECE-managed deployments, repository credential issues, platform vs deployment snapshot behavior, snapshot failures during platform instability.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE snapshot stopped"`, `"ECE snapshot repository misconfigured"`, `"ECE restore failed"`, `"ECE snapshot credentials"`, `"ECE snapshot during instability"`.

## Diagnostic Steps

### 1. ECE Snapshot Architecture
ECE can configure a **platform-level snapshot repository** that applies to all deployments:
- Platform repository: configured in ECE admin console → Platform → Repositories
- Deployments can also have their own custom repositories
- ECE triggers pre-plan-change snapshots automatically before plan changes

### 2. Platform Snapshot Repository Configuration
```bash
# Check configured platform repositories
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform/configuration/snapshots/repositories" | \
  jq '[.[] | {id:.repository_name, type:.config.type}]'

# Check default repository for deployments
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform/configuration/snapshots/repositories/default" | jq '.'
```

### 3. Snapshot Status for a Deployment
```bash
# Recent snapshots via ECE API
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>/snapshots" | \
  jq '.snapshots[-5:] | reverse | .[] | {id:.snapshot_name, state:.state, start:.start_time}'

# Via ES API directly
curl -s -k -u admin:<pass> "https://localhost:9243/<cluster-endpoint>/_snapshot/_all" | jq 'keys'
curl -s -k -u admin:<pass> "https://localhost:9243/<cluster-endpoint>/_snapshot/<repo>/_all?verbose=false" | \
  jq '.snapshots | sort_by(.start_time) | reverse | .[0:5] | map({id:.snapshot, state:.state})'
```

### 4. Snapshots Stopped Running
Common causes:
- Snapshot repository credentials expired or revoked
- Repository bucket/container deleted or inaccessible
- Cluster is red (snapshots require green/yellow cluster)
- A previous snapshot is still in progress (only 1 concurrent snapshot per repo)
- SLM policy disabled or misfired

```bash
# Check SLM policy status
curl -s -k -u admin:<pass> "https://localhost:9243/<cluster-endpoint>/_slm/policy" | \
  jq 'to_entries[] | {policy:.key, status:.value.policy.schedule, last_run:.value.last_success}'

# Check for in-progress snapshot
curl -s -k -u admin:<pass> "https://localhost:9243/<cluster-endpoint>/_snapshot/_status" | jq '.snapshots | length'
```

### 5. Repository Credential Issues
For S3/GCS/Azure repositories, credentials are stored as ES secure settings (keystore):
```bash
# Check if keystore has the required keys
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>/keystore" | \
  jq '.secrets | keys'
```
Required keys by type:
- S3: `s3.client.<name>.access_key`, `s3.client.<name>.secret_key`
- GCS: `gcs.client.<name>.credentials_file`
- Azure: `azure.client.<name>.account`, `azure.client.<name>.key`

```bash
# Verify repository connectivity
curl -s -k -u admin:<pass> "https://localhost:9243/<cluster-endpoint>/_snapshot/<repo>/_verify" | jq '.'
```

### 6. Restore Failures
```bash
# Check cluster health before restore (cluster must be green/yellow)
curl -s -k -u admin:<pass> "https://localhost:9243/<cluster-endpoint>/_cluster/health" | jq '{status:.status}'

# Restore a snapshot
curl -s -k -u admin:<pass> -XPOST \
  "https://localhost:9243/<cluster-endpoint>/_snapshot/<repo>/<snapshot>/_restore" \
  -H "Content-Type: application/json" \
  -d '{
    "indices": ["<index-pattern>"],
    "rename_pattern": "(.+)",
    "rename_replacement": "restored-$1",
    "include_global_state": false
  }' | jq '.'
```
Restore conflict (index already exists):
```bash
curl -s -k -u admin:<pass> -XPOST "https://localhost:9243/<cluster-endpoint>/<index>/_close"
# Then retry restore without rename
```

### 7. Pre-Plan-Change Snapshot Failure
ECE takes a snapshot before each plan change. If the snapshot fails, the plan change may be blocked:
```bash
# Check plan history for snapshot failure
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>" | \
  jq '.plan_info.history[-1].plan_attempt_log | map(select(.step_type | test("snapshot"))) | .[] | {step:.step_type, status:.status, log:.info_log[-1]}'
```
If snapshot timeout: cluster may be under heavy load. Retry the plan change.
If snapshot fails due to no repository: configure a snapshot repository first.

### 8. Snapshot Failures During Platform Instability
If ZooKeeper or coordinator is unstable, ECE-triggered snapshots may fail:
- The snapshot job is initiated by the constructor
- If constructor cannot reach ES, snapshot times out
- Platform stability must be restored before snapshots can succeed

### 9. Custom Repository in ECE
```bash
# Register a custom repository on a deployment
curl -s -k -u admin:<pass> -XPUT \
  "https://localhost:9243/<cluster-endpoint>/_snapshot/<repo-name>" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "s3",
    "settings": {
      "bucket": "<bucket-name>",
      "region": "<region>",
      "client": "default"
    }
  }' | jq '.'
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the snapshot error, repository type, and whether the platform was stable during the failure.

## Token Budget
- Check repository verification first — instantly confirms connectivity.
- SLM policy status shows if automation is configured and recent run status.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
