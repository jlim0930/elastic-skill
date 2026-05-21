---
name: apm-upgrade-compatibility
description: Diagnoses APM Server upgrade failures, APM agent-to-server version compatibility, breaking changes in APM intake API between versions, index template migrations after APM Server upgrade, and APM integration version skew in Fleet.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# APM Server — Upgrade & Compatibility Sub-Agent

Scope: APM Server upgrade failures, agent-server version skew, breaking changes in intake API, index template conflicts after upgrade, APM integration version skew in Fleet.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"APM Server upgrade failed"`, `"APM agent server version compatibility"`, `"APM intake API breaking changes"`, `"APM Server 8 upgrade"`, `"APM integration version skew Fleet"`.

## Diagnostic Steps

### 1. Version Inventory
```bash
# APM Server version
curl -s http://localhost:8200/ | jq '{ok:.ok, version:.version}'
# Fleet-managed APM Server
pgrep -a apm-server 2>/dev/null | head -1

# Elasticsearch version
curl -s http://localhost:9200 | jq '.version.number'

# APM integration version (Fleet)
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/epm/packages/apm" \
  | jq '{version:.item.version}'
```

### 2. APM Agent Compatibility Matrix
APM agents have version compatibility requirements with APM Server:
```bash
# Check events in traces index for agent versions
curl -s "http://localhost:9200/traces-apm*/_search?size=5&sort=@timestamp:desc" \
  -H "Content-Type: application/json" \
  -d '{"_source":["agent.name","agent.version","service.name"]}' \
  | jq '.hits.hits[]._source'
```
General compatibility: APM agents communicate with APM Server via the intake API. Older agents (6.x) may use intake v1 (not supported in APM Server 8.x).

### 3. Intake API Version Changes
APM Server 8.x uses intake v2 API exclusively.
```bash
# Test intake v1 (deprecated/removed in 8.x)
curl -s -X POST http://localhost:8200/v1/transactions -H "Content-Type: application/json" -d '{}' | jq '.'
# Test intake v2 (current)
curl -s -X POST http://localhost:8200/intake/v2/events -H "Content-Type: application/x-ndjson" -d '{}' | jq '.'
```

### 4. Index Template Migration After Upgrade
APM 7.x used `.apm-*` legacy indices. APM 8.x uses data streams (`traces-apm-*`):
```bash
# Check for legacy indices
curl -s "http://localhost:9200/_cat/indices/.apm-*?v&h=index,docs.count" | head -10
# Check data streams
curl -s "http://localhost:9200/_data_stream/traces-apm*" | jq '.data_streams | length'
```
After upgrade 7→8: legacy indices remain readable but new data goes to data streams.
Run APM setup to create new templates:
```bash
apm-server setup --index-management -c /etc/apm-server/apm-server.yml
```

### 5. APM Integration Upgrade in Fleet
```bash
# Check current APM integration version
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/epm/packages/apm" \
  | jq '.item.version'

# List available versions
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/epm/packages/apm?full=true" \
  | jq '.item.latestVersion'
```
Fleet → Integrations → APM → Settings → Update to upgrade the integration.

### 6. Upgrade Procedure (Standalone)
```bash
# 1. Backup config
cp /etc/apm-server/apm-server.yml /etc/apm-server/apm-server.yml.bak

# 2. Stop APM Server
systemctl stop apm-server

# 3. Upgrade package
# RPM: yum update apm-server
# DEB: apt-get install --only-upgrade apm-server
# Tarball: replace binary

# 4. Test config
apm-server test config -c /etc/apm-server/apm-server.yml

# 5. Run setup for new templates/pipelines
apm-server setup -c /etc/apm-server/apm-server.yml

# 6. Start APM Server
systemctl start apm-server
```

### 7. Upgrade Order
Correct order when APM Server is self-managed:
1. Upgrade Elasticsearch
2. Upgrade Kibana
3. Upgrade APM Server
4. Upgrade APM agents (can be gradual)

### 8. Deprecated Config Options
```bash
# Check for deprecated config in current version
apm-server test config -c /etc/apm-server/apm-server.yml 2>&1 | grep -E "deprecated|warning|removed"
```
APM 7→8 breaking changes:
- `apm-server.frontend` section removed
- `apm-server.rum` auth configuration changed
- Fleet mode configuration removed from standalone config

### 9. KCS + Docs Lookup
Execute retrieval protocol with the version numbers (from, to) and specific upgrade error.

## Token Budget
- Version inventory (APM Server, ES, agents) before any log analysis.
- `apm-server test config` catches deprecated options without starting.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
