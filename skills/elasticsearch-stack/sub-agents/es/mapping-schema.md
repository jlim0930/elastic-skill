---
name: es-mapping-schema
description: Diagnoses Elasticsearch dynamic mapping surprises and conflicts, field type errors causing indexing rejection, ECS alignment issues, keyword vs text mistakes, nested/object mapping confusion, runtime field performance issues, mapping explosion from too many fields, and index template priority conflicts.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — Mapping & Schema

**Purpose**: Identify why documents are rejected or fields behave unexpectedly, and prescribe mapping or template fixes.

## Use When
- `mapper_parsing_exception` or `failed to parse field` errors on indexing
- Field not aggregatable or not searchable as expected
- Template not applying the expected mapping
- Mapping explosion (too many fields)

## Do Not Use When
- Ingest pipeline transforming before mapping → es/ingest-pipeline
- ILM/rollover creating wrong index structure → es/ilm

## Inputs Needed
- Exact error message (`mapper_parsing_exception`, `strict_dynamic_mapping_exception`, etc.)
- Field name and conflicting types
- Index template name and priority
- Field count on the affected index

## Diagnostic Logic

### Error Classification
| Error | Cause | Fix |
|---|---|---|
| `mapper [<field>] of different type` | Type conflict across indices | Standardize mapping in template; reindex |
| `failed to parse field [<field>]` | Value doesn't match declared type | Fix data source or use `ignore_malformed: true` |
| `object mapping for [<field>] tried to parse as object` | Scalar where object expected | Align data structure to mapping |
| `strict_dynamic_mapping_exception` | New field on strict mapping | Add field explicitly or change dynamic mode |

### Field Count Thresholds
- < 200 fields = healthy
- 200–1000 fields = review dynamic mapping settings
- > 1000 fields = mapping explosion risk; performance impact
- > 10,000 fields = critical; cluster state updates slow

### Dynamic Mapping Modes
| Mode | Behavior | Risk |
|---|---|---|
| `true` (default) | Auto-maps all new fields | Mapping explosion |
| `false` | Unmapped fields stored but not searchable | Silent data loss on search |
| `strict` | Rejects documents with unmapped fields | 400 errors if data changes |
| `runtime` | New fields computed at query time | Slow aggregations |

### Keyword vs Text
| Type | Use For | Aggregatable | Full-Text |
|---|---|---|---|
| `text` | Analyzed/tokenized search | No | Yes |
| `keyword` | Exact match, aggs, sorting | Yes | No |

- `"field is not aggregatable"` → field is `text` without a `.keyword` sub-field
- Fix: add multi-field mapping with `.keyword` sub-field
- Cannot change type after creation — must reindex

### Template Priority
- Higher `priority` value wins when multiple templates match an index name
- Simulate winning template: `POST /_index_template/_simulate_index/<index_name>`
- Component templates composed in order — later ones override earlier ones for same field path
- Check which template applies before creating an index to avoid surprises

### Nested vs Object
- `object`: sub-fields flattened into document root; cross-field correlation LOST
- `nested`: stored as separate hidden documents; cross-field queries work correctly
- `"nested query on non-nested path"` → declared as `object`, not `nested`
- Returning too many results on nested query → path declared wrong type

### Runtime Field Performance
- Runtime fields computed at query time from `_source` — not indexed
- High-cardinality runtime scripts on large indices = very slow searches
- Runtime aggregations scan all documents — no index-level optimization
- For frequently-used derived fields: materialize at ingest time instead

### ECS Field Type Requirements
| Field | Required Type | Common Mistake |
|---|---|---|
| `@timestamp` | `date` | `keyword` or `text` |
| `event.dataset` / `event.module` | `keyword` | `text` |
| `source.ip` / `destination.ip` | `ip` | `text` or `keyword` |
| `http.response.status_code` | `long` | `keyword` |
| `event.duration` | `long` (nanoseconds) | `float` |

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for mapper_parsing_exception, strict_dynamic_mapping_exception
→ [error_pattern_matching](../../../../shared/error_pattern_matching.md) — classify mapping errors before diagnosis

## KCS Queries
`"mapper_parsing_exception field type conflict elasticsearch"`, `"mapping explosion too many fields"`, `"keyword text aggregation elasticsearch"`, `"nested object mapping elasticsearch difference"`

## Output
Report: error type, affected field and conflicting types, field count, template priority winner, fix (reindex / add sub-field / change dynamic mode).
