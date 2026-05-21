---
name: es-observability-data
description: Diagnoses Elasticsearch logs/metrics/traces not indexing correctly, data stream naming and template issues, ECS field incompatibilities, integration package field mismatches, monitoring data gaps, stack monitoring collection failures, APM trace ingestion issues, and Fleet-managed integration data gaps.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — Observability Data

**Purpose**: Identify why logs, metrics, or traces are missing or malformed in Elasticsearch and prescribe the fix.

## Use When
- Data stream missing expected documents
- ECS field type conflicts blocking integration data
- Stack monitoring data gap (last doc > 10 min ago)
- APM traces not appearing in Kibana APM UI
- Fleet-managed integration data gap

## Do Not Use When
- Agent not enrolling or offline → elastic-agent/enrollment
- Kibana visualization showing wrong data → kibana/dashboard-visualization
- Cluster health affecting data stream → es/cluster-health first

## Inputs Needed
- Data type missing: logs, metrics, or traces
- Data stream name (pattern: `<type>-<integration>.<dataset>-<namespace>`)
- Integration/source name (Fleet integration, APM, custom)
- Last successful document timestamp

## Diagnostic Logic

### Data Stream Status Check
- `status: RED` → backing index health issue → fix cluster health first
- `status: YELLOW` → replica shards missing → check node count vs replica setting
- Missing data stream → no template matched the index pattern → check template and index pattern

### Template Verification
- Data must arrive to an index name matching a template's `index_patterns`
- Simulate what template applies: `POST /_index_template/_simulate_index/<expected_index_name>`
- Missing template or wrong priority → data stream cannot be created on first document
- Integration packages install component templates — custom templates with wrong priority can override

### Observability Naming Convention
| Type | Pattern |
|---|---|
| Logs | `logs-<integration>.<dataset>-<namespace>` |
| Metrics | `metrics-<integration>.<dataset>-<namespace>` |
| Traces | `traces-<integration>.<dataset>-<namespace>` |

- Wrong namespace → data going to different data stream than expected
- Custom application indexing to wrong pattern → no template matches → no ILM, no ECS

### ECS Field Type Requirements
| Field | Required Type | Common Mistake |
|---|---|---|
| `@timestamp` | `date` | `keyword`, `text`, or missing |
| `event.dataset` / `event.module` / `log.level` | `keyword` | `text` |
| `source.ip` / `destination.ip` | `ip` | `text` or `keyword` |
| `http.response.status_code` | `long` | `keyword` |
| `event.duration` | `long` (nanoseconds) | `float` |

- ECS type violations → ingestion errors or Kibana display failures
- Integration package upgrade may change field types → check for mapping conflicts after upgrade

### Stack Monitoring Data Gaps
- Last document timestamp > 10 min → collector issue, not ES indexing
- Two monitoring modes — do NOT mix:
  - **Internal**: ES ships metrics directly to `.monitoring-*` indices
  - **Elastic Agent**: Agent collects from ES APIs and ships to monitoring cluster
- Both configured simultaneously → duplicate data or gaps; disable internal when using Elastic Agent

### APM Trace Ingestion
- APM data streams: `traces-apm-<namespace>`, `metrics-apm.*-<namespace>`, `logs-apm.error-<namespace>`
- Zero docs in traces → APM Server connectivity to ES or APM ingest pipeline failures
- APM Server logs (not ES logs) are the first place to check for connectivity and rejection errors
- Verify `apm*` ingest pipelines are present and not failing

### Fleet Integration Data Gaps
- Agent offline or not checking in → no data collected (check at Fleet level first)
- Ingest pipeline error at ES → data rejected silently unless `on_failure` captures it
- Wrong namespace in agent policy → data stream created in unexpected location
- Package not upgraded → stale field mappings causing type conflicts with newer ECS versions

### Integration Package Conflicts
- Package installs component templates at specific field types
- Custom component template with same field at different type → ingestion failure
- After package upgrade: re-simulate the index template to verify no conflicts

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for data stream errors, ingest pipeline rejections
→ [error_pattern_matching](../../../../shared/error_pattern_matching.md) — classify ingestion errors before routing

## KCS Queries
`"logs metrics not indexing data stream elasticsearch"`, `"ECS field incompatibility elasticsearch integration"`, `"stack monitoring collection failed data gap"`, `"APM traces not appearing elasticsearch"`

## Output
Report: data stream status, template match result, ECS violation or naming mismatch, root cause, fix.
