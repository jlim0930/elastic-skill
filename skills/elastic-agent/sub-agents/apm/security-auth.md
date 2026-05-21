---
name: apm-security-auth
description: Diagnoses APM Server security and authentication issues including secret token misconfiguration, API key invalid, anonymous access settings, Elasticsearch authentication from APM Server, and RBAC/role issues for APM data access in Kibana.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# APM Server — Security & Auth Sub-Agent

Scope: Secret token misconfiguration, API key invalid/revoked, anonymous access, ES auth failures from APM Server, RBAC roles for APM data in Kibana, agent 401/403 errors.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"APM Server secret token 401"`, `"APM Server API key invalid"`, `"APM anonymous access"`, `"APM Elasticsearch authentication failed"`, `"APM RBAC role access denied"`.

## Diagnostic Steps

### 1. Auth Errors in APM Logs
```bash
grep -E "401|403|unauthorized|forbidden|secret.*token|api.*key|auth.*fail" \
  /var/log/apm-server/apm-server | tail -20
```

### 2. Secret Token Configuration
```bash
# Standalone: check secret token setting
grep -E "secret_token|auth_token" /etc/apm-server/apm-server.yml 2>/dev/null

# Fleet-managed: check in agent config
grep -r "secret_token" /opt/Elastic/Agent/data/elastic-agent-*/inputs.d/ 2>/dev/null
```
Three auth modes:
- **No secret token**: any agent can send (development only)
- **Secret token**: agents must send `Authorization: Bearer <token>` header
- **API key**: agents use `Authorization: ApiKey <base64-encoded>` header

### 3. Test Auth Headers
```bash
# Test with correct secret token
curl -s -H "Authorization: Bearer <secret_token>" \
  -X POST http://localhost:8200/intake/v2/events \
  -H "Content-Type: application/x-ndjson" \
  -d '{}' | jq '.'

# Without auth (should return 401 if secret token is set)
curl -s -X POST http://localhost:8200/intake/v2/events \
  -H "Content-Type: application/x-ndjson" \
  -d '{}' | jq '.'
```

### 4. API Key Authentication
```bash
# Check if API keys are enabled
grep -E "api_key:" /etc/apm-server/apm-server.yml 2>/dev/null

# Verify an API key exists and is valid
curl -s -u elastic:<pass> "http://localhost:9200/_security/api_key?name=<key_name>" \
  | jq '.api_keys[] | {name:.name, invalidated:.invalidated, expiration:.expiration}'
```
API key requires `manage_api_key` cluster privilege on the APM Server's ES credentials.

### 5. Anonymous Access
```bash
grep -A5 "anonymous:" /etc/apm-server/apm-server.yml 2>/dev/null
```
Anonymous access allows agents to send without auth (for development/testing only).
If disabled in production, all agents must use secret token or API key.

### 6. APM Server → Elasticsearch Auth
APM Server authenticates to ES using credentials configured in `output.elasticsearch`:
```bash
grep -A15 "output.elasticsearch:" /etc/apm-server/apm-server.yml 2>/dev/null \
  | grep -E "username|api_key|password|token"
```
Test ES auth from APM Server host:
```bash
curl -s -u <apm_user>:<pass> http://localhost:9200/_cluster/health | jq '.status'
```
APM Server's ES user needs privileges to index into `traces-apm*`, `logs-apm*`, `metrics-apm*`.

### 7. ES Privileges for APM
Minimum ES privileges for APM Server's ES user:
```bash
curl -s -u elastic:<pass> "http://localhost:9200/_security/user/<apm-user>" \
  | jq '.[].roles'
```
Required roles/privileges:
- `cluster`: `monitor`, `manage_index_templates`, `manage_ilm`, `manage_ingest_pipelines`
- `indices`: read/write on `traces-apm*`, `logs-apm*`, `metrics-apm*`, `.apm-*`

### 8. Kibana APM Role-Based Access
In Kibana, APM data access is controlled by Elasticsearch index-level security:
```bash
curl -s -u elastic:<pass> "http://localhost:9200/_security/role/apm_user" | jq '.'
```
Built-in roles for APM:
- `apm_user`: read-only access to APM data
- `apm_system`: used by APM Server itself

If users can't see APM data in Kibana: verify their ES role grants read access to `traces-apm*` and related indices.

### 9. KCS + Docs Lookup
Execute retrieval protocol with the auth error type (401/403), APM version, and ES cluster version.

## Token Budget
- `curl` auth test before log analysis to isolate the auth issue.
- `grep` for 401/403/auth in APM server logs.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
