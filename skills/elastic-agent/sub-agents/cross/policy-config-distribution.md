---
name: cross-policy-config-distribution
description: Diagnoses cross-component policy and configuration distribution issues including Fleet policy not reaching agents, integration config errors affecting multiple components, policy revision conflicts, and configuration drift between expected and applied state.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Cross-Component — Policy & Config Distribution Sub-Agent

Scope: Fleet policy not reaching agents, integration config errors affecting multiple components, policy revision conflicts, configuration drift, multi-component policy validation.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Fleet policy not applied agents"`, `"Elastic Agent policy revision conflict"`, `"Fleet integration config error"`, `"agent policy configuration drift"`, `"Fleet policy version mismatch"`.

## Diagnostic Steps

### 1. Current Agent Policy State
```bash
# What policy is the agent currently running?
elastic-agent inspect 2>/dev/null | grep -E "policy_id|revision|version" | head -10

# Fleet view: list agents and their policy
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/agents?perPage=20" \
  | jq '.items[] | {id:.id, status:.status, policy_id:.policy_id, policy_revision:.policy_revision}'
```

### 2. Policy Revision Mismatch
```bash
# Expected revision (from Fleet API)
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/agent_policies/<policy-id>" \
  | jq '.item.revision'

# Actual revision running on agent
elastic-agent inspect 2>/dev/null | grep "revision"
```
If agent revision < Fleet revision: agent hasn't received the latest policy.
Check agent check-in status (see `agent/health-checkin.md`).

### 3. Policy Application Errors
```bash
grep -E "apply.*policy|policy.*error|integration.*error|failed.*configure" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -20
```

### 4. Integration Configuration Validation
Each integration in a policy has its own config. Invalid integration config causes the component to fail:
```bash
# Inspect applied inputs from current policy
elastic-agent inspect --output yaml 2>/dev/null | grep -A5 "inputs:" | head -30
```
Common integration config errors:
- Missing required fields (e.g., Logstash hosts not set)
- Wrong data type (string where int expected)
- Path not accessible to the agent process

### 5. Fleet Policy → Agent Pipeline
Policy flow: Kibana Fleet → `.fleet-policies` index → Fleet Server → Agent check-in response → Agent applies.
```bash
# Check if policy is in ES
curl -s "http://localhost:9200/.fleet-policies/_search?size=1&sort=@timestamp:desc" \
  | jq '.hits.hits[0]._source | {policy_id:.policy_id, revision:.revision_idx, "@timestamp":"@timestamp"}'

# Check if Fleet Server is delivering policies
grep -E "policy.*deliver|checkin.*response|policy.*update" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -10
```

### 6. Forcing Policy Re-Application
```bash
# Restart elastic-agent to force policy re-fetch
systemctl restart elastic-agent

# Or from Fleet UI: Fleet → Agents → [agent] → Actions → Request diagnostics / Restart
```

### 7. Output Configuration Distribution
If output (ES, Logstash) is changed in Fleet, all agents must receive the new output config:
```bash
# Check current output config applied to agent
elastic-agent inspect --output yaml 2>/dev/null | grep -A10 "outputs:" | head -15
```

### 8. Cross-Component Config Consistency
When Beats are managed alongside Elastic Agents in the same cluster:
- Beats use their own `filebeat.yml` / `metricbeat.yml` (not Fleet policies)
- Verify output URLs match across all components
```bash
grep -E "hosts:|host:" /etc/filebeat/filebeat.yml /etc/metricbeat/metricbeat.yml 2>/dev/null
```

### 9. Policy Tamper Detection
If an agent is manually reconfigured:
```bash
# Check if agent config matches what Fleet expects
elastic-agent inspect --output yaml > /tmp/actual_config.yaml
# Compare with Fleet policy (diff manually or use Fleet UI's "Review changes")
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific policy error and components involved.

## Token Budget
- `elastic-agent inspect` gives current policy state without reading log files.
- `curl` Fleet API for policy revision before log analysis.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
