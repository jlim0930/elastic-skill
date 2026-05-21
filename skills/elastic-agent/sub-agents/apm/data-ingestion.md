---
name: apm-data-ingestion
description: Diagnoses APM Server data ingestion failures including no data appearing in Kibana APM UI, intake endpoint errors, event validation failures, dropped transactions/spans, and APM data stream indexing issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# APM Server — Data Ingestion Sub-Agent

Scope: No APM data in Kibana, intake endpoint errors, event validation failures, dropped transactions/spans/errors/metrics, APM data stream indexing issues.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"APM Server no data Kibana"`, `"APM intake endpoint error"`, `"APM Server event validation failed"`, `"APM transactions not indexed"`, `"APM data stream indexing error"`.

## Diagnostic Steps

### 1. APM Server Intake Endpoint Health
```bash
# Fleet-managed APM (port 8200 default)
curl -s http://localhost:8200/ | jq '{ok:.ok, version:.version}'
curl -s http://localhost:8200/healthz | jq '.'

# Check APM server is listening
ss -tlnp | grep 8200
```

### 2. Ingestion Errors in APM Logs
```bash
# Fleet-managed APM: logs via Elastic Agent
grep '"level":"error"' /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson \
  | jq -r '.message' | grep -i "apm\|intake\|ingest" | tail -20

# Standalone APM server logs
grep -E "ERROR|WARN|intake.*error|event.*invalid|failed.*index" \
  /var/log/apm-server/apm-server | tail -30
```

### 3. Test Intake Endpoint
Send a minimal test event to verify intake is working:
```bash
# Send a test transaction (APM v2 intake API)
curl -s -X POST "http://localhost:8200/intake/v2/events" \
  -H "Content-Type: application/x-ndjson" \
  -d '{"metadata":{"service":{"name":"test","version":"1.0","agent":{"name":"test","version":"1.0"}}}}'$'\n''{}'
```
Expected: `{}` or `{"accepted": 1}`. Error response = intake processing issue.

### 4. APM Data Streams
```bash
# Check APM data streams exist
curl -s "http://localhost:9200/_data_stream/traces-apm*" | jq '[.data_streams[].name]'
curl -s "http://localhost:9200/_data_stream/logs-apm*" | jq '[.data_streams[].name]'
curl -s "http://localhost:9200/_data_stream/metrics-apm*" | jq '[.data_streams[].name]'

# Check recent indexing
curl -s "http://localhost:9200/traces-apm*/_count" | jq '.count'
```
No data streams = APM index template not loaded.

### 5. Index Template Setup
```bash
# For standalone APM: run setup
apm-server setup --index-management -c /etc/apm-server/apm-server.yml

# Check APM templates
curl -s "http://localhost:9200/_index_template/traces-apm*" | jq 'keys'
```

### 6. Event Validation Failures
Events can be dropped if they fail validation:
```bash
grep -E "invalid|validation|decode.*error|malformed|schema" \
  /var/log/apm-server/apm-server | tail -20
```
Common causes:
- Agent sending events with wrong format for the server version
- Missing required fields (service name, agent name)
- Payload too large (default max payload: 300MB)

### 7. Bulk Indexing Errors
```bash
grep -E "429|bulk.*error|index.*failed|write.*rejected" \
  /var/log/apm-server/apm-server | tail -10
```
ES rejecting bulk requests = 429 or write thread pool rejection. Check:
```bash
curl -s "http://localhost:9200/_cat/thread_pool/write?v&h=name,active,queue,rejected"
```

### 8. APM Agent vs Server Compatibility
Check agent version compatibility with APM Server version:
```bash
curl -s http://localhost:8200/ | jq '.version'
# Agents send their version in intake events — check logs for version mismatch
grep -E "agent.*version|unsupported.*agent" /var/log/apm-server/apm-server | tail -10
```

### 9. KCS + Docs Lookup
Execute retrieval protocol with APM Server version, agent language, and specific error.

## Token Budget
- Intake health check and data stream count give instant signal.
- `grep` for ERROR/WARN in logs before reading full log file.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
