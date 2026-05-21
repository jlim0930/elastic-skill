---
name: agent-diagnostics
description: Diagnoses hard-to-interpret Elastic Agent logs, missing diagnostics bundle, subprocess log inspection, monitoring Elastic Agent health, dataset-specific log review, and correlating Fleet UI status with local logs.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Elastic Agent — Observability & Diagnostics Sub-Agent

Scope: agent logs hard to interpret, missing diagnostics bundle, subprocess log inspection, monitoring Elastic Agent health, dataset-specific log review, correlating Fleet UI status with local logs.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"elastic-agent diagnostics bundle"`, `"elastic-agent log interpretation"`, `"elastic-agent subprocess logs"`, `"elastic-agent monitoring health"`, `"elastic-agent Fleet UI correlation"`.

## Diagnostic Steps

### 1. Generate Diagnostics Bundle
```bash
elastic-agent diagnostics
# Saves to current directory as elastic-agent-diagnostics-<timestamp>.zip
ls -lh elastic-agent-diagnostics-*.zip
```
Bundle contains: agent logs, status output, config (redacted), and system info.

### 2. Inspect Bundle Contents
```bash
unzip -l elastic-agent-diagnostics-*.zip | head -40
unzip elastic-agent-diagnostics-*.zip -d diag_out/
ls diag_out/
```
Key files in bundle:
- `elastic-agent.json` / `*.ndjson` — main agent logs.
- `elastic-agent-status.json` — component status at time of collection.
- `elastic-agent-config.yaml` — effective config (credentials redacted).
- Subprocess logs: `filebeat-*.json`, `metricbeat-*.json`, etc.

### 3. Log Structure (NDJSON)
Agent logs are in NDJSON format. Filter efficiently:
```bash
# All errors
grep '"level":"error"' /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -30

# Last 15 minutes
awk -v cutoff="$(date -u -v-15M '+%Y-%m-%dT%H:%M' 2>/dev/null || date -u --date='15 minutes ago' '+%Y-%m-%dT%H:%M')" \
  '$0 >= cutoff' /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | grep '"level":"error"' | tail -20

# Parse with jq
jq -r 'select(.level == "error") | [.timestamp, .message] | @tsv' \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson 2>/dev/null | tail -20
```

### 4. Subprocess Log Locations
```bash
ls /opt/Elastic/Agent/data/elastic-agent-*/logs/
```
Subprocess logs (Filebeat, Metricbeat, etc.) are in the same directory with different prefixes:
```bash
# Filebeat subprocess errors
grep '"level":"error"' /opt/Elastic/Agent/data/elastic-agent-*/logs/filebeat-*.ndjson 2>/dev/null | tail -20

# APM Server subprocess errors
grep '"level":"error"' /opt/Elastic/Agent/data/elastic-agent-*/logs/apm_server-*.ndjson 2>/dev/null | tail -20

# Endpoint Security subprocess errors
grep '"level":"error"' /opt/Elastic/Agent/data/elastic-agent-*/logs/endpoint-*.ndjson 2>/dev/null | tail -10
```

### 5. Agent Status Correlation
```bash
elastic-agent status --output json | jq '{
  state: .state,
  message: .message,
  failed_components: [.components[] | select(.state != "HEALTHY") | {name: .name, state: .state, message: .message}]
}'
```
Cross-reference with Fleet UI: Fleet → Agents → select agent → Activity tab.
Activity tab shows policy application history; Status tab shows current health.

### 6. Fleet UI Status vs Local Status
| Fleet UI | Local `elastic-agent status` | Likely Cause |
|---|---|---|
| Offline | Running | Network/connectivity issue — agent can't reach Fleet Server |
| Online | FAILED | Component crash — Fleet still has last check-in cached |
| Updating | HEALTHY | Upgrade in progress — expected transient |
| Unhealthy | HEALTHY | Stale Fleet state — wait for next check-in |

### 7. Dataset-Specific Log Review
```bash
# Find logs for a specific integration dataset
grep -r "<dataset_name>\|<integration_name>" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/*.ndjson | grep '"level":"error"' | tail -20
```

### 8. Monitoring Agent Health via Elasticsearch
Agent self-monitoring data is indexed to `.fleet-agent-metrics-*`:
```bash
curl -s "http://localhost:9200/.fleet-agent-metrics-*/_search?size=1&sort=@timestamp:desc" \
  | jq '.hits.hits[0]._source | {timestamp:."@timestamp", agent_id:.agent.id, status:.agent.status}'
```

### 9. KCS + Docs Lookup
Execute retrieval protocol now with the specific error from logs or the status mismatch pattern.

## Token Budget
- `elastic-agent diagnostics` + `jq` on the bundle is the most efficient approach for complex issues.
- `grep '"level":"error"'` on NDJSON logs before any broader log reading.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
