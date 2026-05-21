---
name: es-search-performance
description: Diagnoses Elasticsearch slow searches, query timeouts, expensive aggregations, search threadpool saturation, stuck long-running tasks, poor cache hit rates, and deep pagination misuse with scroll/PIT.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — Search Performance

**Purpose**: Identify why searches are slow or timing out and determine whether the cause is query design, resource saturation, or cache miss.

## Use When
- Search latency is elevated or inconsistent
- Search threadpool showing queued or rejected requests
- Specific queries timing out
- Dashboard slow (after confirming ES is the bottleneck, not Kibana)

## Do Not Use When
- Indexing is slow without search complaints → es/indexing-performance
- Cluster is red/yellow → es/cluster-health first

## Inputs Needed
- Thread pool queue/rejected counts for `search`
- Slow log entries (query, took duration, index)
- Recent changes (new dashboard, new query, index growth)

## Diagnostic Logic

### Thread Pool First
- `search.rejected` > 0 → cluster cannot keep up; requests dropped
- `search.queue` sustained > 50 → backpressure; add capacity or reduce load
- Check `search_coordination` pool if using async search

### Long-Running Searches
- Identify tasks running > 30s via `_tasks?actions=*search*`
- Cancel via `_tasks/<id>/_cancel` if causing resource drain
- Set `search.default_search_timeout` cluster-wide to prevent runaway queries

### Slow Log Analysis
Filter slow log for entries with `SLOW` marker. Extract:
- Query source (which aggregation or filter is slow)
- Index name (which index is the bottleneck)
- Duration (sort by highest `took`)

### Expensive Query Patterns
| Pattern | Problem | Fix |
|---|---|---|
| `wildcard`/`regexp` on large field | Full shard scan | Prefix queries or n-gram index |
| High-cardinality `terms` agg | Large heap allocation per shard | Use `composite` agg + pagination |
| `match_all` + large `size` | Fetching too many docs | Use `search_after` + PIT |
| `script_score` | Runs on every doc | Pre-filter or cache |
| `from + size > 10,000` | Deep pagination rejected | Switch to PIT + `search_after` |

### Cache Hit Rates
- **Query cache**: filter context queries; invalidated by index churn or `now`-based filters
- **Request cache**: aggregation-only (`size:0`) queries; use consistent `preference`
- Low hit rate with repeated queries = uncacheable filters (use `now/1h` rounding)

### Segment Pressure Impact on Search
- High segment count (>200/shard) → slow searches even with simple queries
- Appears as `SegmentMerger` in hot threads during searches
- Fix: forcemerge read-only indices to 1 segment

## Shared Skills
→ [performance_triage](../../../../shared/performance_triage.md) — identify if search or write is the bottleneck
→ [log_filtering](../../../../shared/log_filtering.md) — filter slow log for SLOW entries

## KCS Queries
`"slow search query elasticsearch"`, `"search threadpool rejected"`, `"aggregation timeout memory"`, `"deep pagination scroll pit"`

## Output
Report: threadpool state, slowest query pattern, cache hit rate, root cause, recommended fix.
