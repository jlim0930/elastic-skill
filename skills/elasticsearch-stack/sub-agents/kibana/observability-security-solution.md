---
name: kb-observability-security-solution
description: Diagnoses Kibana APM/Logs/Metrics UI not showing data, Security detection rules failing, Cases and connector issues, Uptime/Synthetics display problems, Fleet integration asset installation failures, and Security app privilege configuration issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# KB — Observability / Security Solution

**Purpose**: Identify why Observability or Security UI is not showing data or detection rules are failing, and prescribe the fix.

## Use When
- APM Services UI shows no data despite agents sending data
- Security detection rules in `error` or `failed` state
- Fleet integration package installation failed
- Uptime or Synthetics showing no monitors

## Do Not Use When
- Data missing from ES (not UI) → es/observability-data
- Rule privileges → kibana/alerting-rules
- Kibana performance → kibana/performance

## Inputs Needed
- Solution area (APM, Logs, Metrics, Security, Uptime/Synthetics)
- Data stream name and document count
- Error message from rule execution or package install
- User's Kibana feature privileges for the solution

## Diagnostic Logic

### APM UI — No Data
- APM data streams: `traces-apm-*`, `logs-apm.*-*`, `metrics-apm.*-*`
- Zero docs in these streams → APM Server not forwarding data, wrong output config, or wrong namespace
- APM Server logs (not ES/Kibana logs) are the first place to check for connectivity and rejection errors
- Verify `apm` integration is installed and active in Fleet

### Logs / Metrics UI — No Data
- Logs UI uses data view `logs-*` by default; Metrics UI uses `metrics-*`
- Data exists in ES but UI shows nothing → data view pattern doesn't match actual index names
- Check the data view configuration matches the actual data stream names

### Security Detection Rules
| Failure Message | Cause | Fix |
|---|---|---|
| `index_not_found_exception` | Source data index doesn't exist | Verify data stream; check Fleet agent status |
| `Insufficient privileges` | Rule API key lacks index read | Re-create rule as user with correct ES role |
| `No indices match the pattern` | Data view pattern too specific | Update rule index pattern |
| `Query failed` | Invalid EQL or KQL in rule | Test query in Discover first |
| `Task timed out` | Rule query too slow | Optimize query; increase rule interval |

- Detection rules require source data (`logs-*`, `winlogbeat-*`) AND write access to `.alerts-security.alerts-<space>`
- If rule API key was created by user whose role later changed → re-create rule with correct user

### Fleet Integration Asset Installation
- Installation failures: ES cluster health issue; insufficient Kibana `fleet_admin` role; version incompatibility
- Fix cluster health first if ES is unhealthy — package installation creates index templates
- Check `.fleet-*` system indices health as a secondary check

### Cases and Connectors
- Cases require: `cases: ["all"]` for create/update; `cases: ["read"]` for view only
- Connector management requires `actions: ["all"]`
- External connector failures (Jira, ServiceNow) → check `is_missing_secrets` on connector

### Uptime / Synthetics — No Data
- Uptime uses `heartbeat-*` (Heartbeat agent); Synthetics uses `synthetics-*`
- Private monitors require Elastic Agent with Synthetics integration installed and registered
- No private location shown in UI = Synthetics integration not registered with Fleet

### Security App Privileges
- Full Security app access requires `siem: ["all"]` and `cases: ["all"]` in Kibana + ES role with `read` on source indices and `read`/`write` on `.alerts-security.alerts-*`
- Missing `siem` Kibana privilege → Security app hidden or empty
- Missing ES index privilege → detection rules fail to query source data

## Shared Skills
→ [authentication_checks](../../../../shared/authentication_checks.md) — verify privilege gaps for solution features
→ [log_filtering](../../../../shared/log_filtering.md) — filter for detection rule errors, APM, Fleet asset install patterns

## KCS Queries
`"kibana APM UI no data services empty"`, `"kibana detection rule failed security insufficient privileges"`, `"kibana fleet integration asset install failed"`, `"synthetics heartbeat uptime kibana no data"`

## Output
Report: solution area, data stream status, rule failure reason or privilege gap, fix.
