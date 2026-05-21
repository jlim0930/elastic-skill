---
name: kb-performance
description: Diagnoses Kibana slow page loads, heavy dashboards with many panels or high-cardinality aggregations, Node.js heap memory pressure, browser-side rendering bottlenecks, task manager load impacting responsiveness, saved object query slowness on large .kibana indices, and slow Elasticsearch queries behind Kibana API calls.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# KB — Performance

**Purpose**: Identify whether Kibana slowness is caused by ES queries, Node.js memory, task manager, or browser rendering, and prescribe the fix.

## Use When
- Kibana pages taking > 5s to load
- Dashboard loading slowly (most panels)
- Kibana process consuming excessive memory
- Background task processing degrading UI

## Do Not Use When
- Single dashboard panel slow → kibana/dashboard-visualization (check specific panel)
- Kibana not starting → kibana/startup-availability
- ES cluster health degraded → fix ES first

## Inputs Needed
- Kibana Status API output (heap %, response time avg/max)
- Task manager drift from `_health` API
- Whether slowness is consistent or only during peak
- Browser DevTools: are API calls slow, or is rendering slow?

## Diagnostic Logic

### Performance Thresholds (Status API)
| Metric | Warning | Critical |
|---|---|---|
| `heap_used / size_limit` | > 75% | > 90% |
| `resp_time_avg` | > 2000ms | > 5000ms |
| Task manager `drift.p99` | > 5000ms | > 10000ms |

### Bottleneck Identification — Two Paths
1. **ES query bottleneck**: API calls in browser DevTools Network tab take > 1s → diagnose ES query
2. **Browser rendering bottleneck**: API calls return quickly (< 500ms) but UI still slow → reduce panel count, simplify visualizations

### Node.js Memory (Kibana Heap)
- Default max heap: ~1.4 GB
- Heap > 75%: GC pressure; Kibana responses slow
- Increase: `node.options: ["--max-old-space-size=2048"]` (in kibana.yml)
- Maximum safe: ~50% of system RAM; restart required after change

### Task Manager Load Impact
- Task manager competes with user requests for Kibana CPU
- High drift → rules executing late AND UI responses slower
- Fix: reduce active rule count; add Kibana nodes
- Each Kibana node adds task manager workers

### Saved Object Query Slowness
- Kibana queries `.kibana` index for every object list load
- Performance degrades when `.kibana` index is very large

| Object Count | Impact |
|---|---|
| < 10,000 | Negligible |
| 10,000–100,000 | Noticeable list load times |
| > 100,000 | Significantly slow |

- Fix: delete unused dashboards/visualizations; archive old saved objects; split into spaces

### Heavy Dashboard Patterns
| Pattern | Problem | Fix |
|---|---|---|
| `terms` on high-cardinality field | Aggregates millions of unique values | Reduce `size`; use `filters` agg |
| Wide time range + high granularity | Millions of date histogram buckets | Reduce range or increase bucket interval |
| > 20 panels loading simultaneously | Parallel ES queries overwhelm cluster | Reduce panel count |
| Runtime field in aggregation | Computed per doc at query time | Materialize field at ingest |
| `top_hits` aggregation | Fetches full documents per bucket | Replace with `terms` + `date_histogram` |

### Browser-Side Bottleneck Signs
- API calls in Network tab return in < 500ms
- DevTools Performance tab shows > 2s of Scripting or Layout tasks
- Issue is consistent regardless of ES data volume
- Fix: reduce panels; use simpler visualization types; avoid complex Vega/Canvas specs

## Shared Skills
→ [performance_triage](../../../../shared/performance_triage.md) — trace ES query bottleneck vs Kibana processing vs browser
→ [log_filtering](../../../../shared/log_filtering.md) — filter for slow response times, memory errors in Kibana log

## KCS Queries
`"kibana slow performance page load response time"`, `"kibana heavy dashboard aggregation slow ES query"`, `"kibana saved object query slow .kibana index large"`, `"kibana node.js memory heap usage"`

## Output
Report: bottleneck layer (ES query / Node.js heap / task manager / browser), specific metric vs threshold, fix.
