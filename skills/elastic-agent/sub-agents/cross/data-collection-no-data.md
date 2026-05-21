---
name: cross-data-collection-no-data
description: Diagnoses cross-component "no data" issues spanning the full ingestion pipeline from Elastic Agent/Beats through Fleet Server to Elasticsearch including pipeline tracing, integration not producing data, index permission issues, and end-to-end flow validation.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Cross-Component — Data Collection & No Data Sub-Agent

Scope: End-to-end "no data" diagnosis spanning agent→fleet-server→ES pipeline, integration not producing data, missing index permissions, ingest pipeline failures, and full pipeline tracing.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Elastic Agent no data Kibana"`, `"Fleet integration not collecting data"`, `"Elastic Agent data not reaching Elasticsearch"`, `"Beats no data ingested"`, `"APM no data showing"`.

## Diagnostic Steps

### 1. End-to-End Pipeline Triage Checklist
Work through this checklist from source to sink:
```
[ ] 1. Is the agent/beat healthy? (elastic-agent status / ps aux | grep beat)
[ ] 2. Is the integration/input enabled and configured?
[ ] 3. Are source files/services accessible from the agent host?
[ ] 4. Is the agent/beat producing events? (internal metrics)
[ ] 5. Can the agent reach the output (Fleet Server / ES / Logstash)?
[ ] 6. Is the output accepting events? (no 429, no 401/403)
[ ] 7. Are events reaching ES? (index doc count)
[ ] 8. Is the ingest pipeline processing events correctly?
[ ] 9. Are events appearing in Kibana with the right time range?
```

### 2. Agent/Beat Health
```bash
elastic-agent status 2>/dev/null | head -20
ps aux | grep -E "filebeat|metricbeat|elastic-agent" | grep -v grep | wc -l
```

### 3. Input/Integration Status
```bash
# Elastic Agent: inspect active inputs
elastic-agent inspect --output yaml 2>/dev/null | grep -A5 "inputs:" | head -30

# Filebeat: check if harvester is running
curl -s http://localhost:5066/stats | jq '.filebeat.harvester.open_files'
```

### 4. Source Accessibility
```bash
# For log files
ls -la /var/log/nginx/access.log 2>/dev/null
stat /var/log/nginx/access.log | grep -E "Access:|Uid:|Gid:"

# For services (Metricbeat)
curl -s http://localhost/nginx_status 2>/dev/null | head -3
```

### 5. Event Production Rate
```bash
# Elastic Agent internal metrics
curl -s http://localhost:6791/stats 2>/dev/null | jq '.agent' | head -10

# Filebeat internal metrics
curl -s http://localhost:5066/stats | jq '{
  events_added: .filebeat.events.added,
  events_done: .filebeat.events.done,
  output_success: .output.events.acked,
  output_failed: .output.events.failed
}'
```

### 6. Output Connectivity
```bash
# Test ES output
curl -s -u <user>:<pass> http://localhost:9200/_cluster/health | jq '.status'

# Test Fleet Server (for agent check-in)
curl -s https://localhost:8220/api/status | jq '.status'
```

### 7. Events Reaching Elasticsearch
```bash
# Check doc count in relevant indices (last 5 minutes)
curl -s "http://localhost:9200/<index-pattern>/_count" \
  -H "Content-Type: application/json" \
  -d '{"query":{"range":{"@timestamp":{"gte":"now-5m"}}}}' | jq '.count'
```
Replace `<index-pattern>` with the relevant pattern:
- Filebeat nginx: `filebeat-*`
- Elastic Agent: `logs-nginx.access-*`
- APM: `traces-apm-*`
- Metricbeat: `metricbeat-*`

### 8. Ingest Pipeline Issues
```bash
# Check if documents have _ignored fields (failed pipeline processing)
curl -s "http://localhost:9200/<index>/_search?size=1" \
  -H "Content-Type: application/json" \
  -d '{"query":{"exists":{"field":"_ignored"}}}' | jq '.hits.total.value'

# Test ingest pipeline directly
curl -s -X POST "http://localhost:9200/_ingest/pipeline/<pipeline-name>/_simulate" \
  -H "Content-Type: application/json" \
  -d '{"docs":[{"_source":{"message":"sample log line"}}]}' \
  | jq '.docs[].error // .docs[].doc._source | keys'
```

### 9. Kibana Data View / Time Range
If data is in ES but not visible in Kibana:
- Verify the correct data view / index pattern is selected
- Verify time range covers the data's `@timestamp`
- Check if data view field list needs refreshing (Management → Data Views → Refresh)

```bash
# Confirm latest document timestamp
curl -s "http://localhost:9200/<index>/_search?size=1&sort=@timestamp:desc" \
  | jq '.hits.hits[0]._source."@timestamp"'
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific component, integration, and where in the pipeline data stops.

## Token Budget
- Start with doc count in ES — instantly tells you if data is reaching ES or not.
- Work backwards from sink (ES) to source (agent) to isolate the failure layer.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
