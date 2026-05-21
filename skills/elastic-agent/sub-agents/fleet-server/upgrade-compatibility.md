---
name: fleet-server-upgrade-compatibility
description: Diagnoses Fleet Server upgrade failures, version skew with Kibana/Elasticsearch/Agent, policy incompatibility after upgrade, agent enrollment issues after stack upgrade, and known version-specific host URL/default host issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Fleet Server — Upgrade & Compatibility Sub-Agent

Scope: Fleet Server upgrade failures, version skew with Kibana/ES/Agent, policy incompatibility after upgrade, agent enrollment issues after stack upgrade, known version-specific host URL/default host issues.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Fleet Server upgrade failed"`, `"Fleet Server version skew Kibana"`, `"Fleet Server policy incompatible after upgrade"`, `"agent enrollment fails after stack upgrade"`, `"Fleet Server default host URL issue version"`.

## Diagnostic Steps

### 1. Version Inventory
```bash
# Elastic Agent / Fleet Server version
elastic-agent version
# Kibana version
curl -s http://localhost:5601/api/status | jq '.version.number'
# ES version
curl -s http://localhost:9200 | jq '.version.number'
```
Fleet Server version = Elastic Agent version (same binary).
All three should be the same major.minor version.

### 2. Fleet Server Upgrade Failures
Fleet Server is upgraded by upgrading the Elastic Agent running the Fleet Server policy.
```bash
grep -E "upgrade|version|failed.*install|rollback" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -30
```
Upgrade via Fleet UI: Fleet → Agents → select Fleet Server agent → Actions → Upgrade.
If upgrade fails, automatic rollback restores previous version.

### 3. Version Skew Detection
```bash
# Check all agents' versions
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/agents?perPage=100" \
  | jq '[.items[] | {id:.id, version:.agent.version, status:.status}] | group_by(.version) | map({version:.[0].version, count:length})'
```
Agents running newer versions than Fleet Server = unsupported; upgrade Fleet Server first.
Fleet Server should always be >= agent version.

### 4. Upgrade Order
Correct upgrade order:
1. Elasticsearch
2. Kibana
3. Fleet Server (Elastic Agent running FS policy)
4. All other Elastic Agents

Kibana and Fleet Server must be upgraded together (same version).

### 5. Policy Incompatibility After Upgrade
New Fleet/Kibana versions may add required fields to Fleet policies.
```bash
grep -E "policy.*incompatible|unknown.*field|invalid.*policy|schema" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -10
```
Solution: update integration packages to versions compatible with the new Fleet/Agent version.
Fleet → Integrations → select integration → check for available updates.

### 6. Agent Enrollment Failures After Stack Upgrade
If agents fail to enroll after upgrading Fleet Server:
```bash
grep -E "enroll.*fail|token.*invalid|version.*mismatch" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -20
```
Old enrollment tokens remain valid after upgrade. If tokens fail: regenerate them.
Check for known breaking changes in the release notes for the specific version jump.

### 7. Known Version-Specific Issues
Version-specific default Fleet Server URL bugs:
```bash
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/fleet_server_hosts" | jq '.items[] | {name:.name, host_urls:.host_urls}'
```
Some older versions had bugs where the default host URL was set to `localhost` instead of the actual host.
Verify and manually correct in Fleet → Settings → Fleet Server Hosts.

### 8. Post-Upgrade Validation
```bash
# After upgrade, verify:
elastic-agent status
curl -s https://<fleet-server>:8220/api/status | jq '.status'
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/agents?perPage=0" | jq '.statusSummary'
```

### 9. KCS + Docs Lookup
Execute retrieval protocol now with the version numbers and upgrade error.

## Token Budget
- Version inventory in one pass — all three components before reading any log.
- `jq` on Fleet agents API for version distribution across fleet.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
