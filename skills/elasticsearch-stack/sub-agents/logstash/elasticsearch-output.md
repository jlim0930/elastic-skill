---
name: ls-elasticsearch-output
description: Diagnoses Logstash Elasticsearch output bulk 429 rejections, authentication failures (401/403), TLS and certificate validation failures, index/template/data stream misconfiguration, ILM integration issues, retry storm behavior during ES downtime, and version compatibility problems.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# LS — Elasticsearch Output

**Purpose**: Identify why Logstash cannot write to Elasticsearch and prescribe the fix.

## Use When
- 429 rejections from Elasticsearch
- 401/403 authentication errors on output
- TLS/SSL errors connecting to Elasticsearch
- Events not reaching the target index or data stream

## Do Not Use When
- Events not reaching output stage (filter/input problem) → logstash/filter-parsing or logstash/input-connectivity
- Logstash queue backing up → logstash/queueing-backpressure (check ES health first)

## Inputs Needed
- HTTP status code (429, 401, 403, SSL error)
- Auth method in use (username/password, API key, cloud)
- Target: classic index, data stream, or ILM-managed
- ES version vs Logstash output plugin version

## Diagnostic Logic

### Error Classification
| Code/Error | Cause | First Check |
|---|---|---|
| 429 `TOO_MANY_REQUESTS` | ES write thread pool saturated | ES write thread pool queue + rejections |
| 401 Unauthorized | Wrong credentials or expired API key | Verify credential format; check expiry |
| 403 Forbidden | User/key exists but no write permission | Required index privileges: `create_index`, `index`, `create` |
| `SSLHandshakeException` | CA mismatch or cert expired | `cacert` path correct? Cert valid? |
| `ConnectionFailed` | ES unreachable | Port 9200 open from Logstash host? |

### API Key Format (Critical)
- HTTP Authorization header: `ApiKey <base64(id:api_key)>`
- Logstash config `api_key` field: `id:api_key` (colon-separated, NOT base64)
- Using base64 in Logstash config → persistent 401

### 429 Behavior
- Logstash retries 429s indefinitely — this is correct behavior
- Root cause is always ES-side (heap, write thread pool, or merge pressure)
- Fix ES first; Logstash will resume when ES recovers
- Logstash-side mitigation: reduce `pipeline.batch.size` to lower write pressure temporarily

### TLS Configuration
- `cacert` = PEM CA cert that signed the ES server certificate
- `ssl_certificate_verification: false` = disables hostname check (debugging only; never in production)
- Proper fix: provide correct `cacert`; ensure ES cert SAN includes the hostname Logstash connects to
- For mutual TLS: also set `ssl_certificate` and `ssl_key` in output config

### Data Stream Output
- Set `data_stream: true` with `data_stream_type`, `data_stream_dataset`, `data_stream_namespace`
- A matching index template with `data_stream: {}` must exist in Elasticsearch
- Template `index_patterns` must match the resulting stream name
- Do NOT also enable ILM in Logstash output when using data streams — use template-level ILM

### ILM Integration
- Logstash ILM output creates policy, rollover alias, and first index (`-000001` suffix)
- Conflict: index already exists without ILM → `IndexAlreadyExistsException`
- Disable Logstash-managed ILM (`ilm_enabled: false`) when managing ILM externally

### Retry Storms During ES Downtime
- Logstash retries indefinitely on connection errors and 429s
- PQ buffers events during outage if configured
- Monitor queue size growth during outage
- When ES recovers, Logstash drains automatically — no manual intervention needed
- Size PQ for expected maintenance window: `events/sec × outage_seconds × avg_event_bytes`

### Version Compatibility
- Logstash 8.x output plugin with ES 7.x → check compatibility matrix
- Use same major version for both when possible
- Check installed plugin version to determine compatibility

## Shared Skills
→ [authentication_checks](../../../../shared/authentication_checks.md) — auth error classification and API key format
→ [tls_certificate_checks](../../../../shared/tls_certificate_checks.md) — SSL error diagnosis
→ [network_connectivity_checks](../../../../shared/network_connectivity_checks.md) — port reachability to ES

## KCS Queries
`"logstash elasticsearch output 429 rejected bulk"`, `"logstash output authentication failed 401 API key"`, `"logstash elasticsearch TLS certificate cacert"`, `"logstash ILM output data stream configuration"`

## Output
Report: error code, auth method issue, TLS gap, index/stream config mismatch, fix.
