---
name: es-mapping-conflicts
description: Diagnoses Elasticsearch mapping conflicts, field type errors, dynamic mapping issues, and index template problems that cause 400 errors or document rejection.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES Mapping Conflicts Sub-Agent

Scope: field type conflicts, dynamic mapping failures, mapper_parsing_exception, index template mismatches, 400 errors on ingest.

## Retrieval Protocol
Follow [../../../shared/retrieval-protocol.md](../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"mapper_parsing_exception field type"`, `"mapping conflict text keyword"`, `"dynamic mapping template conflict"`.

## Diagnostic Steps

### 1. Identify the Error
From provided error output or `elasticsearch.log`:
```
grep "mapper_parsing_exception\|mapping.*conflict\|failed to parse" elasticsearch.log | tail -50
```
Key error patterns:
- `mapper [<field>] of different type` → same field mapped as different types across indices
- `failed to parse field [<field>]` → document value doesn't match declared type
- `object mapping for [<field>] tried to parse field [<field>] as object, but found a concrete value` → type conflict between object and scalar

### 2. Get Current Mapping
```
GET /<index>/_mapping?pretty
```
Use `jq` to extract the conflicting field only:
```
jq '.["<index>"].mappings.properties["<field>"]'
```

### 3. Check Index Templates
```
GET /_index_template?pretty
GET /_template?pretty
```
Filter to templates matching the affected index pattern. Confirm component template priority order.
Check `priority` field — higher value wins when templates overlap.

### 4. Dynamic Mapping Settings
```
GET /<index>/_settings?pretty&filter_path=**.dynamic*
```
- `"dynamic": "strict"` → any unmapped field = rejection.
- `"dynamic": "false"` → unmapped fields silently ignored (not indexed).

### 5. Simulate Mapping
To test a document against a template without indexing:
```
POST /_index_template/_simulate_index/<index-name>
```
Identifies which template wins and what the resulting mapping would be.

### 6. KCS + Docs Lookup
Execute retrieval protocol now. Query with the exact exception name and field type.

## Token Budget
- Extract conflicting field only from `_mapping` output; never load the full mapping of large indices.
- `grep` for error lines in logs before reading.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../shared/output-format.md](../../../shared/output-format.md).
Reference thresholds from [../../../shared/thresholds.md](../../../shared/thresholds.md).
