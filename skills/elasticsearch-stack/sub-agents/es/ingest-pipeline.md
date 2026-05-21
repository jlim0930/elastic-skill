---
name: es-ingest-pipeline
description: Diagnoses Elasticsearch ingest pipelines not transforming documents correctly, processor failures, Painless script errors, GeoIP/enrich processor failures, on_failure handling gaps, pipeline simulation and debugging, ingest node bottlenecks, and pipeline chaining issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — Ingest Pipeline

**Purpose**: Identify which pipeline processor is failing or producing wrong output and prescribe the fix.

## Use When
- Documents indexed but fields missing or wrong values
- `ingest_pipeline` errors in logs
- Pipeline simulation returns errors
- GeoIP lookup producing no results
- Enrich lookup not enriching documents

## Do Not Use When
- Documents rejected by mapping (not pipeline) → es/mapping-schema
- Logstash pipeline failures (not ES ingest) → logstash/filter-parsing

## Inputs Needed
- Pipeline ID and processor type failing
- Sample document that triggers the failure
- Whether pipeline is attached as `default_pipeline` or `final_pipeline`
- Ingest node stats showing failed count per pipeline

## Diagnostic Logic

### First Step: Simulate with Verbose
- Use `_ingest/pipeline/<id>/_simulate` with `verbose: true`
- Verbose mode shows document state after EACH processor — pinpoints exact failure
- This is faster than reading logs for pipeline logic errors

### Processor Error Classification
| Processor | Common Error | Cause |
|---|---|---|
| `script` | `NullPointerException` | Field doesn't exist in document |
| `script` | `cannot resolve symbol` | Typo in field name; use `ctx['field']` not `ctx.field` for dynamic |
| `grok` | `grok match failed` | Pattern doesn't match input string |
| `date` | `failed to parse date` | Date format mismatch |
| `geoip` | `_geoip_lookup_failure` tag | Private/reserved IP — expected, not an error |
| `enrich` | No enrichment applied | Enrich policy not executed after creation |
| `pipeline` | `pipeline_not_found` | Child pipeline missing |

### Painless Script Guards
- Guard against missing fields: `if (ctx.containsKey('field') && ctx['field'] != null)`
- `ctx['field']` (bracket notation) for dynamic field names; `ctx.field` for static
- Type mismatches: cast explicitly `(String) ctx['field']`
- Test script in isolation using `_ingest/pipeline/_simulate` with an inline pipeline (no save needed)

### GeoIP Processor
- `_geoip_lookup_failure` tag on result = IP not in database (private/reserved) — normal behavior
- Zero GeoIP results on valid public IPs → database may be stale or missing
- Self-managed databases: verify `.mmdb` file path exists and is readable
- Elastic-managed databases: check database status via `_ingest/geoip/stats`

### Enrich Processor
- Two-step setup: (1) create policy, (2) **execute policy** — step 2 is frequently missed
- If enrich index is stale: re-execute the policy to refresh the lookup data
- Slow enrich = large source index; use `max_matches: 1` to limit result set
- Check coordinator queue size in `_enrich/stats` — high queue = enrich overloaded

### on_failure Scoping
- At **processor level**: catches only that processor's failure; remaining processors still run
- At **pipeline level**: catches any uncaught processor failure in the pipeline
- Without `on_failure`: processor error → pipeline aborts → document silently dropped if no `on_failure_pipeline`
- Best practice: route failed documents to a separate failure index for inspection

### Pipeline Attachment
- Pipeline must be set as `default_pipeline` or `final_pipeline` on index settings, OR passed at request level
- `final_pipeline` always runs last, even after `default_pipeline`
- Verify attachment: check `default_pipeline` in index settings — not just that the pipeline exists

### Pipeline Chaining
- `pipeline` processor calls child pipeline by name
- Child pipeline missing → `pipeline_not_found` → parent fails
- Circular references → stack overflow
- Check for circular chains by inspecting each pipeline's `pipeline` processor references

### Ingest Node Performance
- Avg pipeline processing time > 10ms = slow pipeline (check with `_nodes/stats/ingest`)
- `ingest.rejected` > 0 in thread pool → ingest overloaded; scale ingest nodes or simplify pipeline
- Identify bottleneck processor using `_simulate` with `verbose: true` on a representative document

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for ingest_pipeline, processor, on_failure patterns
→ [performance_triage](../../../../shared/performance_triage.md) — if ingest is the bottleneck in the indexing chain

## KCS Queries
`"ingest pipeline processor failed elasticsearch"`, `"geoip processor lookup failure"`, `"enrich processor execute policy missing"`, `"painless script NullPointerException ingest"`

## Output
Report: pipeline ID, failing processor type and index, root cause (null field / stale enrich / missing child pipeline / pattern mismatch), fix.
