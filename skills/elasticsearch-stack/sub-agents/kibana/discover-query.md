---
name: kb-discover-query
description: Diagnoses Kibana KQL/Lucene query syntax errors, Discover slow or timing out, data view misconfiguration, time field/time picker confusion, missing fields or documents in Discover, field caps slowness across large index patterns, and DLS-filtered document counts.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# KB — Discover & Query Experience

**Purpose**: Identify why Discover shows wrong results, is slow, or has query errors, and prescribe the fix.

## Use When
- KQL/Lucene query returning errors or unexpected results
- Discover slow to load or timing out
- Documents present in ES but missing in Discover
- Field not visible in Discover field list

## Do Not Use When
- Data not in ES at all → es/indexing-performance or es/observability-data
- Visualization not rendering → kibana/dashboard-visualization

## Inputs Needed
- Query syntax and error message (if applicable)
- Time range and whether time field is set correctly
- Whether issue affects one user vs all (DLS check)
- Data view pattern and index count

## Diagnostic Logic

### KQL Syntax Rules
| Mistake | Wrong | Correct |
|---|---|---|
| Unquoted value with spaces | `host.name: my host` | `host.name: "my host"` |
| Leading wildcard (KQL) | `*.log` | Switch to Lucene mode |
| Uppercase boolean | `field: x AND y` | `field: x and y` |
| Field reference without brackets | `field == "value"` | `[field] == "value"` is Logstash; in KQL: `field: value` |

- KQL does NOT support: leading wildcards, regex, proximity queries
- Switch to Lucene mode for advanced queries: `*term`, `/regex/`, `field:[1 TO 100]`

### Discover Slow / Timeout Causes
| Cause | Symptom | Fix |
|---|---|---|
| Wide time range | Slow on large data volume | Narrow to 15 min as baseline test |
| Too many indices in pattern | `_field_caps` slow on load | Narrow data view pattern |
| High segment count | Slow despite small time range | Forcemerge old indices |
| Missing time field | All docs scanned (no time filter) | Correct time field in data view |

### Field Caps Slowness
- Kibana calls `_field_caps` on every data view load to build the field list
- Too many indices matching the pattern → > 10s for field list to load
- Fix: narrow data view pattern; delete or archive old indices; use time-based patterns

### Data View Issues
| Issue | Symptom | Fix |
|---|---|---|
| Wrong time field | Time picker has no effect on results | Update time field in data view settings |
| Pattern too broad | Slow, many irrelevant results | Narrow pattern (e.g., `logs-nginx-*` not `logs-*`) |
| Missing field | Field not in field list | Refresh field list in Stack Management > Data Views |
| Data view deleted | "Index pattern not found" | Recreate data view |

### Missing Documents — Diagnosis Path
1. Verify documents exist in ES: check count directly with admin user
2. Check if time picker is the cause: find the actual `@timestamp` of recent documents
3. Check DLS: compare document count between admin user and affected user → different count = DLS filtering

### Field Not in List
- Field not in `_field_caps` → field not mapped, or has `"index": false` (not searchable)
- Field added to new index but data view not refreshed → refresh field list
- Field has `"index": false` → stored but not searchable; cannot appear in Discover filters

### KQL vs Lucene Capability Comparison
| Feature | KQL | Lucene |
|---|---|---|
| Leading wildcard | No | Yes (`*term`) |
| Regex | No | Yes (`/pattern/`) |
| Proximity | No | Yes (`"a b"~2`) |
| Boolean operators | `and`, `or`, `not` (lowercase) | `AND`, `OR`, `NOT` |

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for discover timeout, field_caps slow patterns
→ [authentication_checks](../../../../shared/authentication_checks.md) — if DLS is suspected (compare user vs admin counts)

## KCS Queries
`"kibana discover slow timeout field_caps"`, `"KQL query syntax error kibana"`, `"kibana data view time field missing"`, `"missing documents kibana discover DLS document level security"`

## Output
Report: query error or slowness cause, time field status, DLS indicator (if different counts), fix.
