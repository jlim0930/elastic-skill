---
name: cross-upgrade-lifecycle
description: Diagnoses cross-component upgrade and lifecycle issues including upgrade order across Elastic Agent, Fleet Server, Beats, APM Server, and the Elastic Stack, version skew problems, rolling upgrade coordination, and post-upgrade validation.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Cross-Component — Upgrade & Lifecycle Sub-Agent

Scope: Upgrade order across Elastic Agent/Fleet Server/Beats/APM Server and the Elastic Stack, version skew, rolling upgrade coordination, post-upgrade validation, migration from standalone to Fleet.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Elastic Stack upgrade order"`, `"Elastic Agent Fleet Server upgrade sequence"`, `"Beats APM upgrade compatibility"`, `"version skew Elastic Stack"`, `"rolling upgrade Elastic components"`.

## Diagnostic Steps

### 1. Version Inventory — All Components
```bash
# Elasticsearch
curl -s http://localhost:9200 | jq '.version.number'

# Kibana
curl -s http://localhost:5601/api/status | jq '.version.number'

# Elastic Agent / Fleet Server
elastic-agent version 2>/dev/null

# Beats
filebeat version 2>/dev/null
metricbeat version 2>/dev/null

# APM Server (Fleet-managed)
pgrep -a apm-server 2>/dev/null | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+"

# All agents in Fleet
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/agents?perPage=100" \
  | jq '[.items[] | .agent.version] | group_by(.) | map({version:.[0], count:length})'
```

### 2. Upgrade Order (Canonical)
For upgrading the full Elastic Stack:
```
1. Elasticsearch (rolling upgrade, node by node)
2. Kibana
3. Fleet Server (Elastic Agent running Fleet Server policy)
4. APM Server (Fleet-managed: automatic via Fleet; standalone: manual)
5. Beats (can be gradual — 7.x Beats work with 8.x ES)
6. Elastic Agents (via Fleet bulk upgrade or per-agent)
```
Never upgrade agents before Fleet Server. Fleet Server version ≥ agent version always.

### 3. Version Skew Compatibility
```bash
# Check for version skew in Fleet
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/agents?perPage=100" \
  | jq '.items[] | select(.agent.version != "<expected-version>") | {id:.id, version:.agent.version}'
```
Compatibility rules:
- Kibana and Fleet Server: **must be same version**
- Elastic Agents: same or one minor version behind Fleet Server
- Beats: n-1 minor version against ES is supported
- APM Server (Fleet): version follows Elastic Agent (same binary)

### 4. Fleet-Managed Agent Upgrade
```bash
# Bulk upgrade via API
curl -s -u <user>:<pass> -X POST "http://localhost:5601/api/fleet/agents/bulk_upgrade" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{"agents":"fleet_agent_id:*","version":"<target-version>","source_uri":"<optional>"}' | jq '.'
```
Monitor upgrade progress:
```bash
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/agents?perPage=100" \
  | jq '[.items[] | {id:.id[0:8], status:.status, version:.agent.version}]' | head -20
```

### 5. Post-Upgrade Validation
```bash
# ES cluster health
curl -s http://localhost:9200/_cluster/health | jq '{status:.status, nodes:.number_of_nodes}'

# Agent status
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/agents?perPage=0" \
  | jq '{total:.total, status:.statusSummary}'

# Check for any downgraded agents
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/agents?perPage=100" \
  | jq '[.items[] | select(.status != "online")] | length'
```

### 6. Upgrade Failures and Rollback
If Fleet-managed agent upgrade fails:
```bash
grep -E "upgrade.*fail|rollback|failed.*install" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -20
```
Automatic rollback restores the previous version. Check:
```bash
ls -la /opt/Elastic/Agent/data/ | grep "elastic-agent-"
```
Multiple version directories = rollback is available.

### 7. Beats Upgrade (Non-Fleet)
```bash
# RPM/DEB: upgrade Beats package
apt-get install --only-upgrade filebeat metricbeat auditbeat 2>/dev/null
yum update filebeat metricbeat 2>/dev/null

# Validate config after upgrade (check for deprecated options)
filebeat test config -c /etc/filebeat/filebeat.yml 2>&1 | grep -E "deprecated|removed|error"

# Reload templates
filebeat setup --index-management -c /etc/filebeat/filebeat.yml
```

### 8. APM Agent Upgrade (Application-Side)
APM agents (Java, Python, Node.js, etc.) are upgraded by the application teams:
- They do not need to match APM Server version exactly
- Backward compatibility: agents support the last 3 major APM Server versions

### 9. KCS + Docs Lookup
Execute retrieval protocol with the specific version jump and components involved.

## Token Budget
- Version inventory across all components in one pass before any analysis.
- `jq` on Fleet agents API for version distribution — faster than log analysis.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
