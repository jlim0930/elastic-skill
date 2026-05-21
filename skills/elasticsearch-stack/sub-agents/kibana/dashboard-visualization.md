---
name: kb-dashboard-visualization
description: Diagnoses Kibana visualizations not rendering or showing errors, dashboard panels timing out, Lens configuration issues, TSVB/Maps/Canvas-specific errors, field not aggregatable or searchable errors, runtime field performance impact on visualizations, and shard failure messages in dashboards.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# KB — Dashboard & Visualization

**Purpose**: Identify why a dashboard panel is not rendering or returning wrong results, and prescribe the fix.

## Use When
- Dashboard panel shows error or "No data"
- `shard_failure` messages in panel
- `"Field is not aggregatable"` or `"Field is not searchable"` errors
- Lens formula errors or missing fields

## Do Not Use When
- Kibana performance generally slow → kibana/performance
- Data missing from ES entirely → es/indexing-performance or es/observability-data

## Inputs Needed
- Visualization type (Lens, TSVB, Maps, Canvas)
- Error message from panel or browser console
- Field name and its mapping type
- Whether issue affects all panels or one specific panel

## Diagnostic Logic

### First Check: Browser DevTools
- Open DevTools → Network tab → filter by `/api/` → find slow (>5s) or 4xx/5xx responses
- Console tab → JavaScript errors from visualization rendering
- This identifies whether the error is ES-side (slow/error API response) or browser-side (JS error)

### Panel Error Classification
| Error | Cause | Check |
|---|---|---|
| `shard_failure` | ES query error on some shards | ES logs for shard-level errors |
| `timeout` | ES query too slow | ES search performance; narrow time range |
| `index_not_found_exception` | Data view references deleted index | Refresh or update data view |
| `"Field is not aggregatable"` | Field is `text` without `.keyword` sub-field | Check field mapping type |
| `"Field is not searchable"` | Field has `"index": false` | Cannot search; reindex to change |

### Field Aggregatability
- `"Field is not aggregatable"` → field is `text` type
- Fix options: use `<field>.keyword` sub-field; add `.keyword` mapping in template; use runtime field
- Cannot change existing field type without reindexing

### Data View Issues
| Issue | Symptom | Fix |
|---|---|---|
| Wrong time field | Time picker has no effect | Update time field in data view settings |
| Pattern too broad | Slow field_caps | Narrow to specific pattern |
| Missing field after new index | Field not visible in UI | Refresh field list in Stack Management |
| Stale field list | New field type wrong | Refresh field list |

### Lens Issues
- "No data" → verify time range covers actual data; check with `_count` query
- Truncated breakdown → high-cardinality field; increase `size` in Lens advanced settings
- Formula error → Lens formulas are NOT Painless — use Lens-specific syntax (`count()`, `sum(field)`)
- "Field not found" → data view refreshed but saved visualization references old field name

### TSVB Issues
- Very slow on large indices (different query path than Lens)
- `max_buckets` exceeded → reduce time range or increase bucket interval
- `ignore_throttled` warning → frozen indices in scope

### Maps Issues
- Tiles not loading → Elastic Maps Service (EMS) unreachable (air-gapped) → configure internal EMS URL
- `"Field is not geo_point"` → field mapped as `text`/`keyword` instead of `geo_point`
- Too many points → use geo_grid aggregation layer instead of document layer

### Runtime Field Performance on Visualizations
- Runtime fields computed at query time per document — not indexed
- High-cardinality aggregations on runtime fields scan all documents
- Fix: materialize field at ingest time via ingest pipeline

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for visualization error, shard failure, timeout patterns
→ [performance_triage](../../../../shared/performance_triage.md) — if ES query is the bottleneck

## KCS Queries
`"kibana visualization not rendering error panel"`, `"kibana field not aggregatable text keyword"`, `"kibana dashboard timeout shard failure"`, `"kibana lens formula error no data"`

## Output
Report: visualization type, error message, field mapping issue or query bottleneck, fix.
