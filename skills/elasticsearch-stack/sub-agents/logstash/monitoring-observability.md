---
name: ls-monitoring-observability
description: Diagnoses Logstash monitoring stopped working in Kibana Stack Monitoring, pipeline metrics missing or stale, Node Stats API interpretation, per-pipeline log file separation, central pipeline management visibility issues, and choosing between legacy internal monitoring vs Elastic Agent collection.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# LS — Monitoring & Observability

**Purpose**: Identify why Logstash monitoring data is missing in Kibana or Node Stats API, and prescribe the fix.

## Use When
- Logstash node not appearing in Kibana Stack Monitoring
- Pipeline metrics stale (last data > 10 minutes ago)
- Monitoring data missing after switching from internal to Elastic Agent collection
- CPM pipelines not visible in Kibana

## Do Not Use When
- Pipeline performance issue (not monitoring) → logstash/pipeline-throughput-performance
- Logstash not starting → logstash/pipeline-startup-config

## Inputs Needed
- Monitoring mode configured (internal vs Elastic Agent)
- Last document timestamp in `.monitoring-logstash-*`
- Node Stats API response (from `localhost:9600/_node/stats`)
- Whether CPM is enabled

## Diagnostic Logic

### Two Monitoring Modes — Use Only ONE
| Mode | Config | Target |
|---|---|---|
| Legacy internal | `xpack.monitoring.enabled: true` | `.monitoring-logstash-*` indices |
| Elastic Agent (recommended 8.x+) | Agent policy with Logstash integration | Monitoring cluster via Agent |

- Both modes configured simultaneously → duplicate data or collection gaps
- Disable internal monitoring when using Elastic Agent collection

### Node Stats API (Always Available)
- Local API at `http://localhost:9600/_node/stats` — works regardless of monitoring config
- If API returns 404 or connection refused → Logstash API server not running; check `api.http.port` setting (default 9600)
- Use this as first check before diving into monitoring config

### Monitoring Data Gaps
- Last document timestamp > 10 min → collector issue, not ES indexing
- Zero count in `.monitoring-logstash-*` → Logstash never shipped monitoring data to this cluster
- Stale timestamp → Logstash stopped shipping (check for monitoring errors in log)

### Internal Monitoring Failures
| Error | Cause | Fix |
|---|---|---|
| `logstash_system` user unauthorized | Password changed or user disabled | Update credentials in logstash.yml |
| SSL/TLS error to monitoring cluster | Cert mismatch | Configure `xpack.monitoring.elasticsearch.ssl.cacert` |
| Connection refused | Wrong monitoring cluster host/port | Update `xpack.monitoring.elasticsearch.hosts` |

- The `logstash_system` built-in user must be enabled and have the `logstash_system` role

### Elastic Agent Collection (8.x)
- Agent must be enrolled in Fleet with Logstash integration in its policy
- Agent collects from `http://localhost:9600/_node/stats` by default
- Agent must be on same host as Logstash, or Logstash API must be reachable from Agent host
- Verify metrics data stream exists: check `metrics-logstash.*` data streams

### Per-Pipeline Log Separation
- Enable with `pipeline.separate_logs: true` in logstash.yml
- Creates separate log files per pipeline ID in the log directory
- Useful for multi-pipeline setups where interleaved logs are hard to read
- Per-pipeline log level can also be set in `pipelines.yml`

### CPM Pipeline Visibility
- CPM pipelines managed in Kibana → Stack Management > Logstash Pipelines
- Not appearing in Kibana → connectivity issue or `logstash_admin` user permissions
- Check `xpack.management.logstash.poll_interval` (default 5s)
- Verify Kibana is reachable from Logstash host

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for monitoring failed, exporter error patterns
→ [authentication_checks](../../../../shared/authentication_checks.md) — logstash_system user auth failures

## KCS Queries
`"logstash monitoring not working kibana stack monitoring"`, `"logstash pipeline metrics missing stale"`, `"logstash internal monitoring vs elastic agent 8.x"`, `"logstash centralized pipeline management visibility"`

## Output
Report: monitoring mode, last data timestamp, error type (auth / connectivity / mode conflict), fix.
