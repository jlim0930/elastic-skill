---
name: apm-indexing-schema
description: Diagnoses APM Server indexing and schema issues including mapping conflicts, index template problems, ECS field type errors, APM data stream configuration, ILM/DSL policy issues for APM indices, and custom field conflicts.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# APM Server — Indexing & Schema Sub-Agent

Scope: APM mapping conflicts, index template issues, ECS field type errors, APM data stream configuration, ILM/data stream lifecycle for APM indices, custom field collisions.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"APM Server mapping conflict"`, `"APM index template error"`, `"APM data stream indexing failed"`, `"APM ECS field type conflict"`, `"APM ILM policy"`.

## Diagnostic Steps

### 1. APM Data Streams Overview
```bash
# List all APM data streams
curl -s "http://localhost:9200/_data_stream/traces-apm*,logs-apm*,metrics-apm*" \
  | jq '[.data_streams[] | {name:.name, status:.status, indices_count: (.indices | length)}]'
```
APM data streams follow the pattern:
- `traces-apm-<namespace>` — transactions, spans
- `logs-apm-<namespace>` — application errors, logs
- `metrics-apm-<namespace>` — app/JVM/transaction metrics

### 2. Indexing Errors
```bash
# Check ES logs for APM indexing errors
grep -E "traces-apm\|logs-apm\|metrics-apm" /var/log/elasticsearch/elasticsearch.log \
  | grep -E "ERROR\|mapping.*error\|reject" | tail -20

# Check rejected docs
curl -s "http://localhost:9200/traces-apm*/_search?size=0" \
  -H "Content-Type: application/json" \
  -d '{"query":{"term":{"_ignored":"*"}}}' | jq '.hits.total.value'
```

### 3. Mapping Conflicts
```bash
# Check for mapping type conflicts in APM indices
curl -s "http://localhost:9200/traces-apm*/_mapping" \
  | jq '[to_entries[] | {index:.key, field_count: (.value.mappings.properties | length)}]' | head -20
```
Common APM mapping conflicts:
- Custom labels with different types across services (e.g., `labels.user_id` as long in one service, keyword in another)
- `span.db.statement` exceeding keyword length

### 4. Index Template Check
```bash
# APM index templates
curl -s "http://localhost:9200/_index_template/traces-apm*" | jq '.index_templates[0].name'
curl -s "http://localhost:9200/_component_template/traces-apm-mappings*" | jq '.component_templates[0].name'

# Reload APM templates (standalone)
apm-server setup --index-management -c /etc/apm-server/apm-server.yml
```
If APM templates are missing, events may go to a fallback index with wrong mappings.

### 5. ILM / Data Stream Lifecycle
```bash
# Check ILM policy for APM indices
curl -s "http://localhost:9200/_ilm/policy/traces-apm.policy" | jq '.["traces-apm.policy"].policy.phases | keys'

# Check rollover status
curl -s "http://localhost:9200/traces-apm*/_ilm/explain" \
  | jq '.indices | to_entries[] | select(.value.phase != "hot") | {index:.key, phase:.value.phase}'
```

### 6. Custom Labels and Metadata
APM agents can add custom labels. These create dynamic mappings:
```bash
# Check label field types
curl -s "http://localhost:9200/traces-apm*/_mapping" \
  | jq '.[].mappings.properties.labels.properties | to_entries[] | {field:.key, type:.value.type}' \
  | head -20
```
Avoid dynamic mapping explosions: `labels.*` creates a new field per unique label key.
Configure ignore policy or explicit mappings for high-cardinality label keys.

### 7. Numeric Field Precision
```bash
# Check if any fields are indexed as wrong type
curl -s "http://localhost:9200/traces-apm*/_mapping" \
  | jq '.[].mappings.properties | to_entries[] | select(.value.type == "text") | .key' | head -10
```
Fields that should be `keyword` but are `text` = aggregation failures in APM UI.

### 8. ES Version and APM Feature Compatibility
Some APM features require specific ES versions (e.g., APM correlations, continuous profiling):
```bash
curl -s http://localhost:9200 | jq '.version.number'
curl -s http://localhost:8200 | jq '.version'
```

### 9. KCS + Docs Lookup
Execute retrieval protocol with the specific mapping error and APM/ES versions.

## Token Budget
- Data stream status and count first — instant health signal.
- `jq` to filter mapping output by field name — never print full mapping.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
