---
name: beats-parsing-processing
description: Diagnoses Beats parsing and event processing failures including Grok/dissect pattern errors, JSON decode failures, field mapping issues, timestamp parsing, script processor errors, and pipeline processor failures.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Beats — Parsing & Processing Sub-Agent

Scope: Grok/dissect pattern failures, JSON decode errors, field mapping issues, timestamp parsing, ingest pipeline processor errors, script processor failures, field rename/drop/convert operations.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"filebeat grok pattern not matching"`, `"beats JSON decode error"`, `"filebeat timestamp parse failed"`, `"filebeat dissect pattern"`, `"beats ingest pipeline processor error"`.

## Diagnostic Steps

### 1. Decode/Parse Errors
```bash
grep -E "decode.*error|parse.*error|failed.*parse|unmarshal|json.*error|grok.*no.*match" \
  /var/log/filebeat/filebeat | tail -30
```
Key patterns:
- `failed to JSON decode event` = log line is not valid JSON but `json` processor is configured
- `grok pattern no match` = Grok pattern doesn't match the log format
- `parse error at position` = dissect pattern mismatch

### 2. JSON Processor Configuration
```bash
grep -A15 "processors:" /etc/filebeat/filebeat.yml 2>/dev/null | grep -A8 "json"
```
Common JSON processor issues:
```yaml
# Correct JSON processor config
processors:
  - decode_json_fields:
      fields: ["message"]
      target: ""        # put fields at root
      overwrite_keys: true
      expand_keys: true  # handle dotted keys
```
If the field doesn't exist or contains invalid JSON: processor skips or fails.

### 3. Grok Pattern Testing
```bash
# Install grok debugger tool if available
# Or use online grok debugger with sample log line
grep -E "grok.*pattern|pattern.*grok" /etc/filebeat/filebeat.yml /etc/filebeat/inputs.d/*.yml 2>/dev/null
```
Validate by running Filebeat with `-e` flag and examining event output:
```bash
filebeat -e -c /etc/filebeat/filebeat.yml 2>&1 | grep -E "grok|fields|_grokparsefailure" | head -20
```
Tag `_grokparsefailure` in the document = pattern didn't match.

### 4. Dissect Processor
```bash
grep -A10 "dissect" /etc/filebeat/filebeat.yml 2>/dev/null
```
Dissect is faster than Grok but less flexible. If the format has variable whitespace or optional fields, use Grok instead.
Test dissect token order — every delimiter must be present in the log line.

### 5. Timestamp Parsing
```bash
grep -A5 "timestamp" /etc/filebeat/filebeat.yml 2>/dev/null
grep -E "timestamp.*error|time.*parse|@timestamp" /var/log/filebeat/filebeat | tail -10
```
If `@timestamp` is the ingest time rather than the log time, configure the `timestamp` processor:
```yaml
processors:
  - timestamp:
      field: log.time
      layouts:
        - '2006-01-02T15:04:05.000Z'
      test:
        - '2024-01-15T10:30:00.000Z'
```

### 6. Field Operations (rename, drop, convert, add_fields)
```bash
grep -A30 "processors:" /etc/filebeat/filebeat.yml 2>/dev/null | head -40
```
Check processor order — processors run sequentially. If `rename` comes before `add_fields`, fields may not exist yet.

Drop sensitive fields before sending:
```yaml
processors:
  - drop_fields:
      fields: ["agent.ephemeral_id", "ecs.version"]
      ignore_missing: true
```

### 7. Ingest Pipeline Processor Errors
When using `output.elasticsearch.pipeline`:
```bash
# Check pipeline exists and is valid
curl -s "http://localhost:9200/_ingest/pipeline/<pipeline-name>" | jq '.[]| .processors | length'
# Check for pipeline errors in ES logs
grep -E "ingest.*pipeline.*error|processor.*failed" /var/log/elasticsearch/*.log | tail -10
```
To test a pipeline with a document:
```bash
curl -s -X POST "http://localhost:9200/_ingest/pipeline/<pipeline>/_simulate" \
  -H 'Content-Type: application/json' \
  -d '{"docs":[{"_source":{"message":"sample log line"}}]}' | jq '.docs[].doc._source'
```

### 8. Script Processor Errors
```bash
grep -E "script.*error|painless.*error|script.*failed" /var/log/filebeat/filebeat | tail -10
```
Script processor is an advanced Beats feature. Errors often indicate:
- Null field access without checking existence first
- Type mismatch (string vs int operations)

### 9. KCS + Docs Lookup
Execute retrieval protocol with the specific processor type and error message.

## Token Budget
- `grep` for specific error patterns before reading config or log files.
- Run `filebeat -e` briefly with sample data to capture parse errors live.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
