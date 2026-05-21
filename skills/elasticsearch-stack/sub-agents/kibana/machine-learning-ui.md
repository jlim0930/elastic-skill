---
name: kb-machine-learning-ui
description: Diagnoses Kibana ML app not showing jobs or results due to space isolation or privilege gaps, machine_learning Kibana privilege and monitor_ml/manage_ml ES privilege requirements, datafeed and job wizard errors, anomaly explorer rendering slowness, and ML node availability issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# KB — Machine Learning UI

**Purpose**: Identify why the ML UI is not showing jobs or results, and prescribe the privilege or config fix.

## Use When
- ML jobs exist in ES but don't appear in Kibana ML app
- Anomaly results not showing in Anomaly Explorer
- Job creation wizard validation errors
- Anomaly Explorer rendering slowly

## Do Not Use When
- ML job backend failures (not UI) → es/machine-learning
- ML not licensed or enabled → check ES `_xpack` then return here

## Inputs Needed
- ML availability from `_xpack` (available + enabled)
- Affected user's Kibana ML privilege and ES ML cluster privilege
- Space where jobs were created
- Whether results exist in ES but not visible in Kibana

## Diagnostic Logic

### ML Feature Availability Check
- `ml.available: false` → not licensed; requires Platinum minimum for full ML
- `ml.enabled: false` → disabled in elasticsearch.yml; set `xpack.ml.enabled: true` + restart
- No node with `ml` role → ML jobs cannot open; add `ml` to `node.roles` on at least one node

### Required Privileges
| Access Level | Kibana Privilege | ES Privilege |
|---|---|---|
| Full ML access | `machine_learning: ["all"]` | `manage_ml` |
| Read-only (view results) | `machine_learning: ["read"]` | `monitor_ml` |
| Data access | Same as above | `read` on data indices used by jobs |

- Missing `monitor_ml` → user sees ML app but job list is empty or returns 403
- Missing `read` on `.ml-*` system indices → results visible in API but not UI

### Jobs Not Showing in ML App
- Jobs created in Kibana Space A are tagged to that space → hidden in Space B
- Share job to another space: Kibana ML > Jobs > Manage > Edit > Space assignment
- Alternatively: user lacks `read` on `.ml-anomalies-*` — different from lacking `monitor_ml`

### Results Not Appearing
1. Job never ran → state is `closed` or `failed`; datafeed was never started
2. Datafeed never started → no data fed to job; check datafeed state
3. No anomalies detected → data was within normal bounds; expected behavior
4. Time range doesn't cover job's analysis period → adjust Anomaly Explorer time picker

### Job Creation Wizard Errors
| Error | Cause | Fix |
|---|---|---|
| "Time field must be a date type" | Field mapped as `text` or `keyword` | Use field with `type: date` |
| "No results found for query" | Data view pattern doesn't match data | Verify in Discover first |
| "Bucket span too small" | < 1,000 docs per bucket on average | Increase bucket span |
| "Influencer field not found" | Field not in mapping | Verify field name and mapping |

**Bucket span guidance:**
- 1M+ docs/day → 1 minute; 100k–1M → 15 minutes; 10k–100k → 1 hour; < 10k → 1 day

### Anomaly Explorer Performance
- Heavy rendering causes: many jobs selected simultaneously (> 10), long time range, high-cardinality influencer fields
- Fix: narrow time range; use "Overall" swimlane instead of per-entity; select specific jobs vs "All jobs"
- Use browser DevTools: if API call > 10s → ES query bottleneck; if < 1s → browser rendering bottleneck

### ML Node Capacity
- `ml.max_open_jobs` default: 20 per ML node
- If all slots taken → new jobs queue or fail to open
- `ml.mem.limit` = memory allocated to ML; increase `xpack.ml.max_machine_memory_percent` if needed

## Shared Skills
→ [authentication_checks](../../../../shared/authentication_checks.md) — verify ML privilege gaps for Kibana and ES
→ [log_filtering](../../../../shared/log_filtering.md) — filter for ML wizard errors, anomaly explorer timeout patterns

## KCS Queries
`"kibana ML jobs not showing space privilege"`, `"machine learning UI permission monitor_ml manage_ml"`, `"anomaly explorer slow rendering timeout"`, `"datafeed wizard validation time field bucket span"`

## Output
Report: ML availability status, privilege gap (Kibana/ES), space isolation cause, wizard error, fix.
