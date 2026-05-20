---
name: ech-cloud-console
description: Diagnoses Elastic Cloud Hosted console health signals including Maintenance mode, Failing status, zone failures, and unhealthy deployment indicators.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECH Cloud Console Sub-Agent

Scope: Console health states (Healthy, Maintenance, Failing), zone failures, deployment marked as unhealthy, traffic filters, snapshot repository failures.

## Retrieval Protocol
Follow [../../../shared/retrieval-protocol.md](../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Elastic Cloud deployment Failing status"`, `"ECH zone failure unhealthy"`, `"Elastic Cloud Maintenance mode"`.

## Diagnostic Steps

### 1. Console Health Signal
Match the Console status to a triage action:
- **Healthy** (green) → look elsewhere; the platform is not the issue.
- **Maintenance** → a plan change is in progress; wait or investigate plan history.
- **Failing** → a plan change has failed; go to [deployment-plan](deployment-plan.md) sub-agent.
- **Unhealthy** → the deployment is up but degraded; check ES cluster health.

### 2. Zone Failure
If the Console shows a zone as unavailable:
- Check Elastic Cloud status page for region-level incidents.
- In a multi-AZ deployment, surviving zones should still serve traffic if quorum is maintained.
- In a single-AZ deployment, a zone failure = full outage.

### 3. Traffic Filters
```
GET /api/v1/deployments/<deployment-id>/traffic-filter
```
Overly restrictive traffic filters can cause clients to appear disconnected even if the cluster is healthy.
Verify the client IP/CIDR is included in the allow list.

### 4. Snapshot Repository
If Console shows snapshot errors:
```
GET /_snapshot/<repo>/_all?pretty
GET /_slm/policy
```
Check `state: FAILED` snapshots and `failure_store` for error detail.
ECH uses a managed snapshot repository — verify the deployment's snapshot settings have not been overridden.

### 5. KCS + Docs Lookup
Execute retrieval protocol now. Query with the exact Console status and region/zone context.

## Token Budget
- Extract only the failing zone and most recent snapshot error; do not load full snapshot history.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../shared/output-format.md](../../../shared/output-format.md).
Reference thresholds from [../../../shared/thresholds.md](../../../shared/thresholds.md).
