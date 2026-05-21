---
name: ece-licensing
description: Diagnoses ECE licensing issues including license expired, updated license not applied to deployments, Enterprise Resource Unit license compatibility issues, upgrade blocked by license version, and platform behavior degraded due to licensing problems.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE — Licensing Sub-Agent

Scope: License expired, updated license not applied to deployments, Enterprise Resource Unit (ERU) license compatibility, upgrade blocked by license, platform features degraded due to licensing.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE license expired"`, `"ECE license not applied deployments"`, `"ECE Enterprise Resource Unit"`, `"ECE upgrade license required"`, `"ECE platform feature disabled license"`.

## Diagnostic Steps

### 1. Check Platform License
```bash
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform/license" | \
  jq '{
    type: .license.type,
    expiry: (.license.expiry_date_in_millis | . / 1000 | todate),
    uid: .license.uid,
    max_resource_units: .license.max_resource_units
  }'
```

### 2. License Types in ECE
| License type | Features |
|---|---|
| `basic` | Core Elasticsearch; no security, ML, or advanced features |
| `gold` | Security (TLS, RBAC), monitoring |
| `platinum` | ML, SAML/OIDC, cross-cluster features |
| `enterprise` | All features + ECE multi-stack management |
| `trial` | All features for 30 days |

ECE itself requires an Enterprise (or trial) license. Managed deployments get their license from the platform license.

### 3. License Expired
```bash
# Check expiry in human-readable form
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform/license" | \
  jq '(.license.expiry_date_in_millis / 1000 | todate)'

# Check days remaining
EXPIRY_MS=$(curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform/license" | jq '.license.expiry_date_in_millis')
NOW_MS=$(date +%s)000
echo "Days remaining: $(( ($EXPIRY_MS/1000 - $NOW_MS/1000) / 86400 ))"
```
Expired license: platform features degrade (ML jobs stop, some security features disabled). ECE itself may continue operating but with limited functionality.

### 4. Apply a New License
```bash
# Read license file
cat /path/to/license.json | jq '.'

# Apply license
curl -s -k -u admin:<pass> -XPUT "https://localhost:12443/api/v1/platform/license" \
  -H "Content-Type: application/json" \
  -d @/path/to/license.json | jq '.'
```
The platform license is automatically propagated to all managed deployments.

### 5. License Not Propagated to Deployments
After applying a new platform license, it should propagate to all deployments automatically.
If a deployment still shows an old or expired license:
```bash
# Check individual deployment license
curl -s -k -u admin:<pass> "https://localhost:9243/<cluster-endpoint>/_license" | \
  jq '{type:.license.type, expiry:.license.expiry_date_in_millis}'
```
Manual propagation:
```bash
# Force license update on a specific cluster
curl -s -k -u admin:<pass> -XPUT \
  "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>/license" | jq '.'
```

### 6. Enterprise Resource Unit (ERU) Licensing
ECE uses ERUs (Enterprise Resource Units) to count licensed capacity:
- 1 ERU = 64 GB of deployment RAM
- License includes a maximum ERU count
- Deploying beyond the licensed ERU count may be blocked or generate warnings

```bash
# Check current ERU usage
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform/license" | \
  jq '{max_erus: .license.max_resource_units, type: .license.type}'

# Calculate current RAM usage across all deployments
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch" | \
  jq '[.elasticsearch_clusters[].plan_info.current.plan.cluster_topology[].memory_per_node] | add // 0'
```

### 7. Feature Availability with License Level
When a feature is unavailable, check the license level:
```bash
# Check what features are enabled on a deployment
curl -s -k -u admin:<pass> "https://localhost:9243/<cluster-endpoint>/_xpack/usage?human=true" | \
  jq '{security:.security.enabled, ml:.ml.available, ccr:.ccr.available, monitoring:.monitoring.enabled}'
```
If a feature is disabled: the platform license may not include it. Upgrade the license to the required tier.

### 8. Trial License
For evaluation, ECE can run on a trial license (30 days, all features):
```bash
# Start a trial
curl -s -k -u admin:<pass> -XPOST "https://localhost:12443/api/v1/platform/license/trial/_start" | jq '.'
```

### 9. License Upgrade Blocking
Some ECE version upgrades require an Enterprise license:
```bash
# Check license before upgrade
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform/license" | jq '.license.type'
```
If license type is `basic` or `gold` and the upgrade requires `enterprise`: apply the enterprise license before upgrading.

### 10. KCS + Docs Lookup
Execute retrieval protocol with the license type, expiry date, and the specific feature or upgrade being blocked.

## Token Budget
- License API call gives instant license state.
- Calculate days remaining before any other investigation.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
