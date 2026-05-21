---
name: apm-applications-ui-data-quality
description: Diagnoses APM UI data quality issues including missing services, incomplete traces, missing spans, incorrect latency/throughput metrics, service map not showing dependencies, and correlation/anomaly detection not working.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# APM Server — Applications UI & Data Quality Sub-Agent

Scope: Services missing from APM UI, incomplete traces, missing spans, wrong latency/throughput, service map missing edges, correlations not working, anomaly detection ML issues.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"APM service not showing in Kibana"`, `"APM traces incomplete missing spans"`, `"APM service map no dependencies"`, `"APM latency wrong"`, `"APM correlations not working"`.

## Diagnostic Steps

### 1. Verify Data Is Indexed
```bash
# Check if data exists for the service
curl -s "http://localhost:9200/traces-apm*/_search?size=1" \
  -H "Content-Type: application/json" \
  -d '{"query":{"term":{"service.name":"<service-name>"}}}' \
  | jq '{total:.hits.total.value, latest_ts:.hits.hits[0]._source."@timestamp"}'
```
No data = ingestion issue (see `data-ingestion.md` sub-agent).
Data exists but old = agent is not sending new events.

### 2. Service Name Configuration
APM UI groups events by `service.name`. Check agent configuration:
```bash
# Java
grep -r "elastic.apm.service_name" /etc/app/ /etc/systemd/ 2>/dev/null | head -5
# Node.js
grep -r "serviceName" /app/apm* /app/elastic-apm* 2>/dev/null | head -5
# Python
grep -r "SERVICE_NAME" /app/elasticapm.ini 2>/dev/null
```
Service name must be set, non-empty, and consistent across instances of the same service.

### 3. Incomplete Traces / Missing Spans
Traces show as incomplete when:
- Some spans are dropped (sampling or buffer overflow)
- Downstream services use different trace context propagation format
- Spans are sent with wrong `trace.id` or `transaction.id`

```bash
# Find incomplete traces
curl -s "http://localhost:9200/traces-apm*/_search?size=5" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {"term": {"transaction.sampled": true}},
    "_source": ["trace.id","transaction.id","service.name","@timestamp"],
    "sort": [{"@timestamp":"desc"}]
  }' | jq '.hits.hits[]._source'
```

### 4. Distributed Tracing Context Propagation
For traces to connect across services, all services must:
1. Use compatible trace context format (W3C TraceContext or B3)
2. Pass context headers in outbound requests
3. Read context headers from inbound requests

```bash
# Check if traces span multiple services
curl -s "http://localhost:9200/traces-apm*/_search?size=1" \
  -H "Content-Type: application/json" \
  -d '{"query":{"bool":{"must":[{"range":{"span.id":{"gte":2}}}]}}}' \
  | jq '.hits.total.value'
```

### 5. Service Map Missing Edges
Service map is derived from span destination data:
```bash
# Check for span.destination.service fields
curl -s "http://localhost:9200/traces-apm*/_search?size=1" \
  -H "Content-Type: application/json" \
  -d '{"query":{"exists":{"field":"span.destination.service.name"}}}' \
  | jq '.hits.total.value'
```
0 = agents not capturing exit span destinations. Check agent auto-instrumentation for the specific framework/library.

### 6. Latency/Throughput Metrics Accuracy
APM metrics are stored in `metrics-apm*` data streams as pre-aggregated summaries:
```bash
curl -s "http://localhost:9200/metrics-apm*/_search?size=3&sort=@timestamp:desc" \
  -H "Content-Type: application/json" \
  -d '{"_source":["@timestamp","service.name","transaction.type","transaction.duration.histogram"]}' \
  | jq '.hits.hits[]._source'
```
If metrics show wrong values: check if multiple agent instances are sending with different `service.node.name`.

### 7. APM Correlations
Correlations require at least 1000 transactions to compute:
```bash
curl -s "http://localhost:9200/traces-apm*/_count" \
  -H "Content-Type: application/json" \
  -d '{"query":{"term":{"service.name":"<service-name>"}}}' | jq '.count'
```
< 1000 = correlations may not have enough data.

### 8. Anomaly Detection for APM
APM uses ML jobs for anomaly detection. Check ML job status:
```bash
curl -s -u <user>:<pass> "http://localhost:5601/api/ml/anomaly_detectors" \
  | jq '.jobs[] | select(.job_id | test("apm")) | {id:.job_id, state:.state}'
```
Jobs in `failed` or `closed` state = no anomaly detection. Reopen and restart datafeed.

### 9. Time Zone / Time Range
If APM data shows but queries return no results: verify the Kibana time picker covers the data's time range.
```bash
# Latest document timestamp
curl -s "http://localhost:9200/traces-apm*/_search?size=1&sort=@timestamp:desc" \
  | jq '.hits.hits[0]._source."@timestamp"'
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific APM UI issue and agent language/version.

## Token Budget
- Direct ES query for data existence before any UI debugging.
- `jq` to extract specific fields from search results — never print full documents.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
