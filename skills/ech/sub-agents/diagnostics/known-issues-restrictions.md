---
name: ech-known-issues-restrictions
description: Diagnoses ECH issues caused by documented hosted limitations including behavior caused by known hosted restrictions, region and provider-specific restrictions, stack-version-specific hosted behaviors, unsupported configuration expectations from self-managed Elasticsearch, managed-service boundary confusion, and mapping symptoms to known hosted problems.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECH — Known Issues & Hosted Restrictions Sub-Agent

Scope: Behavior from hosted limitations, region/provider-specific restrictions, stack-version-specific hosted issues, unsupported config expectations (self-managed vs hosted), managed-service boundary confusion, mapping symptoms to known ECH problems.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Elastic Cloud hosted limitation"`, `"ECH restriction not supported"`, `"Elastic Cloud managed service boundary"`, `"ECH region specific issue"`, `"Elastic Cloud version specific behavior"`, `"ECH known issue"`.

## Diagnostic Steps

### 1. Hosted vs. Self-Managed Differences
ECH is a managed service. Many self-managed Elasticsearch configurations are unavailable or behave differently:

| Feature | Self-managed | ECH |
|---|---|---|
| Custom `elasticsearch.yml` | Full control | Limited — some settings locked, others via ECH console |
| File-based users/roles | Supported | **Not supported** — use native realm only |
| Custom JVM options | Full control | Limited via ECH console (heap size) |
| Custom `path.data` / `path.logs` | Configurable | Managed by ECH — not configurable |
| All Elasticsearch plugins | Any plugin | **Approved list only** |
| SSH/direct node access | Available | **Not available** — managed infrastructure |
| X-Pack trial license | Customer-managed | Managed by ECH subscription |
| Log file access (raw) | `/var/log/elasticsearch/` | Console only (Logs and metrics page) |

### 2. Settings That Cannot Be Changed in ECH
The following Elasticsearch settings are managed by ECH and cannot be overridden:
- `cluster.name` — set by ECH (deployment name)
- `node.name` — set by ECH per instance
- `path.data`, `path.logs` — managed by ECH
- `xpack.security.enabled` — always `true`
- `xpack.security.transport.ssl.enabled` — always `true`
- `network.host` — managed by ECH
- `discovery.*` — managed by ECH

Attempting to set these via the ES settings API results in:
- A plan failure (if the setting is validated by ECH)
- A silent no-op (if the setting is overridden by ECH)

Settings that CAN be changed via the ECH console or API:
- `xpack.security.authc.realms.*` — SAML/OIDC/LDAP realm config
- `indices.query.bool.max_clause_count`
- `cluster.routing.*` — routing allocation settings
- Most `index.*` index-level settings

### 3. Region and Provider-Specific Restrictions
Certain ECH features are not available in all regions or cloud providers:

| Feature | Restriction |
|---|---|
| **Autoscaling** | Most regions; newer regions added over time — check release notes |
| **Warm/cold/frozen tiers** | Availability varies by region; check ECH documentation |
| **Specific hardware profiles** | Profile availability varies by region |
| **AWS PrivateLink** | Available on AWS regions only |
| **Azure Private Link** | Available on Azure regions only |
| **GCP Private Service Connect** | Available on GCP regions only |
| **AutoOps** | Available on specific stack versions + regions |

If a feature is missing from the ECH console for your deployment: check whether your region/provider supports it in the Elastic Cloud documentation.

### 4. Stack-Version-Specific Hosted Behaviors
ECH stack versions gate feature availability:

| Feature | Minimum version |
|---|---|
| Fleet Server as hosted component | 7.13+ |
| APM Server as integrated hosted component | 7.13+ (integrated mode); 8.x for managed APM |
| Frozen tier / searchable snapshots | 7.10+ |
| Autoscaling | 7.11+ |
| AutoOps | 8.x (specific minor versions) |
| Data streams | 7.9+ |
| Runtime fields | 7.11+ |

**After a stack version upgrade**, previously available behaviors may change:
- Fleet Server URL may need manual update in Fleet settings
- APM managed component may change configuration format
- Some deprecated settings may stop working silently

### 5. Managed-Service Boundary Confusion
Users sometimes expect self-managed behaviors from ECH. Common patterns:

| "Why can't I..." | ECH answer |
|---|---|
| SSH to the nodes | ECH manages the underlying infrastructure — no node access |
| Set `elasticsearch.yml` directly | Configuration is managed via ECH API/console; some settings are locked |
| Install any plugin | Only the approved plugin list is available for each stack version |
| See raw node disk usage | Use `GET _cat/allocation` from the ES API or the metrics page |
| Prevent ECH from restarting my cluster | ECH performs maintenance; rolling restarts are expected |
| Use the 30-day trial license independently | License is managed by your ECH subscription |
| Run as a single node without replica shards | Single-node is supported with `number_of_replicas: 0` but not recommended for HA |

**For workloads that genuinely need self-managed control**: ECE (on-premise) or ECK (Kubernetes) are alternatives.

### 6. API Rate Limits and Operational Quotas
ECH enforces operational limits:

| Limit | Value |
|---|---|
| Minimum snapshot frequency | 1 per 30 minutes (managed repository) |
| Concurrent plan changes | 1 per deployment (cannot run two plan changes simultaneously) |
| ECH Management API rate limit | Per-organization limit (contact Support for exact values) |
| Maximum deployments per org | Depends on subscription; contact Support |

### 7. Multi-Zone / HA Behavior
ECH deployments can span multiple availability zones:

| Zone config | HA behavior |
|---|---|
| 1 zone | No HA — single AZ failure = full outage |
| 2 zones | Limited HA — no master tiebreaker (split-brain risk); not recommended for production |
| 3 zones | Full HA — one zone can fail without impacting the deployment (recommended) |

If a 1-zone deployment is unavailable because the zone has a platform issue: this is expected behavior for single-zone. Upgrade to 3-zone for production.

### 8. Mapping Symptoms to Known ECH Restrictions
Common symptoms that map to known hosted restrictions:

| Symptom | Known restriction or issue |
|---|---|
| Cannot set `action.auto_create_index: false` | Managed by ECH for system indices |
| Keystore change doesn't apply immediately | Plan change (rolling restart) required — not immediate |
| `elastic` password reset doesn't take effect | Requires plan change (rolling restart) to apply |
| Monitoring shows wrong version for `kibana_system` | ECH-managed internal user; version display is cosmetic |
| ILM stuck with "waiting for shard copy" | Check zone distribution and allocation filters |
| Fleet enrollment fails after ECH stack upgrade | Fleet Server host URL may need manual update in Fleet UI |
| Snapshot every 30 min — cannot change to faster | ECH managed snapshot minimum interval is 30 minutes |
| Cannot disable X-Pack security | Always enabled in ECH |
| Plugin not available in console | Plugin not on approved list for this stack version |
| Cannot use Elasticsearch `_security/privilege` API for application privileges | Supported — but verify application name format |

### 9. Elastic Cloud Status and Known Platform Incidents
For platform-level issues (not customer workload):
- **Elastic Cloud status page**: https://cloud-status.elastic.co
- Incident history shows past outages, maintenance, and root cause analysis
- Region-specific status shows which regions have active incidents

**Always check the status page first** when:
- Multiple deployments in the same region are affected simultaneously
- The issue appeared suddenly with no customer-initiated action
- The ECH console itself is slow or unavailable

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific symptom, the ECH behavior that doesn't match expectations, the stack version, and the cloud provider/region. KCS is the primary source — most known restrictions are already documented.

## Token Budget
- KCS first — known hosted restrictions are usually already documented in KCS.
- Check Elastic Cloud release notes for version-specific changes.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
