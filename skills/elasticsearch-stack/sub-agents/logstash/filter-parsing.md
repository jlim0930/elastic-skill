---
name: ls-filter-parsing
description: Diagnoses Logstash Grok parse failures and pattern optimization, date parsing issues with timezone and locale, mutate logic errors, conditional logic mistakes, Ruby filter exceptions, ECS field normalization problems, and multiline codec handling issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# LS — Filter / Parsing

**Purpose**: Identify which filter is failing or producing wrong output and prescribe the pattern or logic fix.

## Use When
- `_grokparsefailure` or `_dateparsefailure` tags on documents
- Fields missing or wrong values after filter stage
- Ruby filter exceptions in logs
- Multiline events not being merged correctly

## Do Not Use When
- Events not arriving at filter stage → logstash/input-connectivity
- Enrichment-specific failures (GeoIP, DNS, translate) → logstash/processor-enrichment

## Inputs Needed
- Filter type failing (Grok, date, mutate, Ruby, multiline)
- Sample raw message that fails to parse
- Failure tag (e.g., `_grokparsefailure`) and count
- Config file filter block

## Diagnostic Logic

### Error Tag Classification
| Tag | Filter | Cause |
|---|---|---|
| `_grokparsefailure` | grok | Pattern doesn't match input format |
| `_dateparsefailure` | date | Format string doesn't match value |
| `_translatefailure` | translate | Key not in dictionary and no `fallback` |
| Custom tag | ruby | Exception in `begin/rescue` block |

### Grok Pattern Issues
- Test patterns using Kibana > Dev Tools > Grok Debugger (fastest approach)
- `%{GREEDYDATA}` is expensive — anchor with surrounding context
- Multiple patterns: list in order of frequency with `break_on_match: true` (default)

| Issue | Example | Fix |
|---|---|---|
| Pattern too strict | `%{IP}` when hostname possible | Use `%{IPORHOST}` |
| Missing optional section | Date not always present | Wrap in `(?:...)?` |
| Pattern not reaching end | Extra text after last pattern | Add `%{GREEDYDATA:remainder}` |
| Slow alternation | `(a\|b\|c\|...)` | Split into multiple `match` entries |

### Date Filter Issues
| Problem | Fix |
|---|---|
| Locale-dependent month (Jan vs Ene) | Add `locale => "en"` |
| Missing timezone | Add `timezone => "America/New_York"` |
| Subsecond precision | Use `yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ` |
| Unix timestamp | Use `match => ["timestamp", "UNIX"]` or `"UNIX_MS"` |

### Mutate Filter Guards
- `convert` fails if field contains non-numeric string → guard with regex conditional
- `rename` fails silently if source field doesn't exist → guard with `if [field]`
- `split` on nil → guard with `if [field]`

### Ruby Filter Safety
- Always wrap Ruby code in `begin/rescue` to prevent pipeline aborts
- `NoMethodError: undefined method 'to_i' for nil:NilClass` → field is nil; use `event.get('field')&.to_i`
- `event.get('field')` / `event.set('field', value)` — use API methods, not direct hash access
- Avoid external HTTP calls inside Ruby filter — blocks pipeline worker thread

### Conditional Logic Rules
- Field reference requires brackets: `[field]`, not bare `field`
- Truthy check: `if [field]` (not nil, not false, not empty string)
- Regex match: `if [field] =~ /pattern/`
- Tag check: `if "tag" in [tags]`
- String equality: `if [field] == "value"` (not `=`, which is assignment)

### Multiline Handling
- `multiline` codec must be on the **input**, not a filter
- `negate: true` + `what: "previous"` = lines NOT matching pattern append to previous event
- `negate: false` + `what: "next"` = lines matching pattern prepend to next event
- Multiline requires single stream per input worker — not suitable for parallel senders to same port

### ECS Field Normalization
- Rename source fields to ECS paths using `mutate { rename => {...} }`
- Use `labels.*` namespace for custom key-value pairs — avoids conflicts with ECS reserved fields
- Do NOT use top-level custom fields (conflicts with ECS namespace)

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for parse failure tags and filter error patterns
→ [error_pattern_matching](../../../../shared/error_pattern_matching.md) — classify filter errors before routing

## KCS Queries
`"logstash grok parse failure pattern optimization"`, `"logstash date filter parsing timezone locale"`, `"ruby filter exception NullPointerException logstash"`, `"multiline codec logstash input"`

## Output
Report: filter type, failure tag and count, root cause (pattern/format/null/ordering), fix.
