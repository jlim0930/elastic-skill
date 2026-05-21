# Log Filtering

**Purpose**: Reduce log noise to relevant signals before analysis.

## Always Filter First
Never read a full log. Reduce to relevant lines before reasoning.

## Filter by Severity
- Target: `ERROR`, `FATAL`, `WARN`, `CRITICAL`, `Exception`, `rejected`, `circuit_breaking`
- Ignore: `INFO`, `DEBUG`, `TRACE` unless specifically needed for timing

## Filter by Component
Match the failing component: `cluster`, `shard`, `ilm`, `pipeline`, `tls`, `auth`, `kibana`, `task_manager`

## Filter by Time Window
- Start from time of first reported symptom
- Go back 5–15 min before symptom for context
- Ignore lines outside the relevant window

## Filter by Correlation
- Find the first error occurrence (not repeats)
- Trace cascade: find the root error, then the downstream effects
- Common cascade: network/TLS error → auth failure → shard unavailability → rejection

## What to Extract
- First occurrence of the error
- Stack trace root cause (bottom of stacktrace = origin)
- Any "caused by" chain
- Node name, index, pipeline, or component mentioned

## Log Locations by Component
- Elasticsearch: `/var/log/elasticsearch/`
- Kibana: `/var/log/kibana/`
- Logstash: `/var/log/logstash/`
- Beats/Agent: `/var/log/<beat>/` or `/var/log/elastic-agent/`
- Deprecation: `elasticsearch_deprecation.log`
- Slow log: `*_index_search_slowlog.log`, `*_index_indexing_slowlog.log`
- GC log: `gc.log` in ES data directory

## Key Patterns by Issue Type
| Issue | Pattern |
|---|---|
| OOM / Heap | `OutOfMemoryError`, `heap`, `circuit_breaking`, `GcOverheadLimit` |
| Network/TLS | `SSLHandshake`, `connection refused`, `ECONNREFUSED`, `certificate` |
| Auth | `401`, `403`, `authentication failed`, `unauthorized` |
| Shard | `unassigned`, `allocation failed`, `shard failed`, `INDEX_READ_ONLY` |
| ILM | `failed_step`, `policy not found`, `rollover`, `phase transition` |
| Pipeline | `processor`, `grok`, `NullPointerException`, `parse_exception` |
| Migration | `migration`, `REINDEX_FAILED`, `FATAL`, `migrat.*error` |
