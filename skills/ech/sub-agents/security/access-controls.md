---
name: ech-access-controls
description: Diagnoses ECH access control issues including deployment-level access restrictions, hosted security settings misunderstandings, Kibana spaces and feature controls, document-level security (DLS), field-level security (FLS), privilege model confusion, and API key scoping in hosted deployments.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECH — Access Controls Sub-Agent

Scope: Deployment-level access restrictions, hosted security settings, Kibana spaces and feature controls, document-level security (DLS), field-level security (FLS), privilege model confusion, API key scoping.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECH role privilege restriction"`, `"Elastic Cloud Kibana space access"`, `"ECH document level security"`, `"Elastic Cloud field level security"`, `"ECH hosted security settings"`, `"Elastic Cloud Kibana feature control"`.

## Diagnostic Steps

### 1. Role Privilege Model
ECH uses the standard Elasticsearch RBAC. A role defines:
- **Cluster privileges**: what cluster-level actions the user can do
- **Index privileges**: which indices and what operations on those indices
- **Kibana privileges**: which Kibana applications and features the user can access

```bash
# Check a specific role definition
GET _security/role/<role-name>

# Test what a user can do (faster than reading role definitions)
POST _security/user/<username>/_has_privileges
{
  "cluster": ["monitor", "manage_ilm"],
  "index": [{"names": ["logs-*"], "privileges": ["read", "write", "create_index"]}],
  "application": [{"application": "kibana-.kibana", "privileges": ["feature_discover.all"], "resources": ["space:default"]}]
}
```

### 2. Common Privilege Mistakes
| Operation failing | Missing privilege | Fix |
|---|---|---|
| Kibana UI loads but shows nothing | `monitor` cluster privilege | Add `monitor` to role |
| Cannot write to index | `write` or `create_index` on index pattern | Add to role index privileges |
| ILM operations failing | `manage_ilm` cluster + `manage` on index | Add both to role |
| Snapshot operations failing | `create_snapshot` cluster + `manage` on repository | Add to role |
| Cannot see Kibana feature (e.g., APM) | Kibana feature privilege missing | Add feature privilege to role |
| Cannot manage users/roles | `manage_security` cluster privilege | Add to role |
| Fleet/Agent enrollment failing | `fleet_admin` or specific Fleet privileges | Check Fleet privilege requirements |

### 3. Kibana Spaces
Kibana Spaces partition the Kibana environment:
```bash
# List all spaces (Kibana API)
GET /api/spaces/space

# Check a user's role — do they have Kibana privileges for the correct space?
GET _security/role/<role-name> | jq '.[].kibana | map({spaces:.spaces, base:.base, features:.feature})'
```

Symptom: user logs in but sees no saved objects, dashboards, or visualizations:
- They may be in the **wrong space** (different space has different saved objects)
- They may have no **space access** in their role (space must be listed in role's Kibana section)
- Role may be applied to `*` spaces but the user is in a custom space with no matching saved objects

```bash
# To grant access to a specific space in a role
PUT _security/role/<role-name>
{
  "kibana": [{
    "spaces": ["my-space"],
    "base": ["read"],
    "feature": {}
  }]
}
```

### 4. Kibana Feature Controls
Within a space, access to specific Kibana features is controlled per role:
```bash
# Check role's Kibana feature privileges
GET _security/role/<role-name> | jq '.[].kibana[0].feature'
```

Feature privilege levels: `all` / `read` / `none`

Common feature access issues:
- User can see Kibana but cannot access APM/ML/Alerting/Fleet: missing feature privilege
- User can access Discover but not Dashboard: `feature_dashboard` not in role
- User can create but not delete saved objects: missing `delete` sub-privilege

```bash
# Add a specific feature privilege
PUT _security/role/<role-name>
{
  "kibana": [{
    "spaces": ["*"],
    "feature": {
      "discover": ["all"],
      "dashboard": ["read"],
      "apm": ["all"]
    }
  }]
}
```

### 5. Document-Level Security (DLS)
DLS restricts which documents a user can see within an index:
```bash
# Check if DLS is applied to a role for specific indices
GET _security/role/<role-name> | jq '.[].indices | map(select(.query != null)) | map({names:.names, query:.query})'
```

DLS silently filters documents — users see fewer results than expected without an error message.

If DLS query is wrong (malformed or references a field that doesn't exist): user sees zero documents.
```bash
# Test the DLS query directly as if it were a search
GET <index>/_search
{
  "query": <paste-the-dls-query-here>
}
```

### 6. Field-Level Security (FLS)
FLS restricts which fields a user can see within documents:
```bash
# Check FLS on a role
GET _security/role/<role-name> | jq '.[].indices | map(select(.field_security != null)) | map({names:.names, grant:.field_security.grant, except:.field_security.except})'
```

FLS behaviors:
- `grant: ["field1", "field2"]`: user sees **only** these fields (allowlist)
- `except: ["password", "ssn"]`: user sees all fields **except** these (denylist)

FLS can conflict with Kibana: if Kibana requires a field that is excluded by FLS, features may break partially.

### 7. Hosted Security Settings — What Cannot Be Changed in ECH
Some Elasticsearch security settings are managed by ECH and cannot be overridden:

| Setting | ECH behavior |
|---|---|
| `xpack.security.enabled` | Always `true` — cannot disable |
| `xpack.security.transport.ssl.enabled` | Always `true` |
| `xpack.security.http.ssl.enabled` | Always `true` |
| File-based realm | Not supported |
| `network.host` | Managed by ECH |
| Anonymous access | Possible but must be configured via ECH console settings |

```bash
# Check which security settings are active
GET _xpack/usage?human=true | jq '.security | {enabled:.enabled, have_realm_settings:.have_realm_settings}'
```

Attempting to set locked settings via API results in a plan failure or a silent no-op.

### 8. API Key Scoping
API keys in ECH can be created with restricted privileges (role descriptors):
```bash
# Create a scoped API key
POST _security/api_key
{
  "name": "read-only-logs",
  "role_descriptors": {
    "read-logs": {
      "cluster": ["monitor"],
      "indices": [{"names": ["logs-*"], "privileges": ["read"]}]
    }
  },
  "expiration": "30d"
}
```

Rules for scoped API keys:
- A scoped API key cannot have **more** privileges than the creating user
- If the creating user is deleted, the key becomes invalid
- API key privileges are the intersection of the user's privileges AND the key's role descriptors

```bash
# Check an API key's role descriptors
GET _security/api_key?id=<key-id> | jq '.api_keys[0].role_descriptors'
```

### 9. Anonymous Access in ECH
ECH does not enable anonymous access by default. To enable for specific use cases (RUM/APM source maps, public Kibana):
```bash
# Check if anonymous access is configured
GET _nodes/settings | jq '.nodes | to_entries[0].value.settings | to_entries | map(select(.key | test("anonymous"))) | map(.key)'
```

Anonymous access must be configured in the ES settings (not available via secure settings — requires ECH console settings API).

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific access control type (DLS/FLS/Kibana space/role/API key), the operation being blocked, the observed error, and the user/role involved.

## Token Budget
- `_security/role` and `_has_privileges` give instant access control picture.
- Test DLS query directly before debugging role assignment.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
