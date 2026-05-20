---
name: es-ilm-data-streams
description: Diagnoses ILM policy errors, rollover failures, tier migration problems, and data stream issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES ILM and Data Streams Sub-Agent

Scope: ILM policy stuck, rollover failures, shrink/force-merge errors, tier migration blocked, data stream backing index issues.

## Retrieval Protocol
Follow [../../../shared/retrieval-protocol.md](../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ILM stuck phase"`, `"rollover failed alias"`, `"shrink allocation failed"`, `"data stream backing index"`.

## Diagnostic Steps

### 1. ILM Explain
```
GET /<index>/_ilm/explain
```
Key fields: `phase`, `action`, `step`, `failed_step`, `step_info`.
- `step_info.reason` → most informative error detail.
- `failed_step` = `check-rollover-ready` → alias or conditions misconfigured.
- `failed_step` = `shrink` → target node has insufficient space or allocation constraint.
- `failed_step` = `wait-for-yellow-step` → cluster not yellow-or-better; resolve cluster health first.

### 2. ILM Service Status
```
GET /_ilm/status
GET /_cluster/settings?flat_settings&filter_path=*.indices.lifecycle*
```
If `"operation_mode": "STOPPED"` → restart ILM: `POST /_ilm/start`.

### 3. Index Template and Alias Check
```
GET /_index_template/<template>
GET /_alias/<alias>
```
- Rollover requires: either a data stream or a write alias pointing to exactly one index.
- Missing alias = `IllegalArgumentException` in `step_info`.

### 4. Tier Migration
Check nodes have the correct `node.roles` for target tier (`data_hot`, `data_warm`, `data_cold`, `data_frozen`).
```
GET /_cat/nodes?v&h=name,node.role
GET /_cluster/allocation/explain?body={"index":"<index>","shard":0,"primary":true}
```
No warm-tier nodes → ILM waits indefinitely for tier placement.

### 5. Data Streams
```
GET /_data_stream/<name>
GET /_data_stream/<name>/_stats
```
Check backing index count; if write index is read-only, rollover is blocked.

### 6. KCS + Docs Lookup
Execute retrieval protocol now. Use `failed_step` value as primary query term.

## Token Budget
- Use `jq '.indices | to_entries[] | select(.value.failed_step != null)'` on ILM explain bulk output.
- Never load full index template list; filter with `?name=<pattern>`.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../shared/output-format.md](../../../shared/output-format.md).
Reference thresholds from [../../../shared/thresholds.md](../../../shared/thresholds.md).
