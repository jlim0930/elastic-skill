---
name: agent-policy-configuration
description: Diagnoses Elastic Agent policy not updating on agents, wrong policy assigned, integration config not rendered as expected, output settings misconfiguration, Fleet Server host misconfiguration, standalone vs Fleet-managed confusion, and agent policy conflicts.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Elastic Agent — Policy & Configuration Sub-Agent

Scope: policy not updating on agents, wrong policy assigned, integration config not rendered as expected, output settings misconfiguration, Fleet Server host misconfiguration, default Fleet Server host issues, standalone vs Fleet-managed confusion, agent policy conflicts across environments.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"elastic-agent policy not updating"`, `"elastic-agent wrong policy assigned"`, `"elastic-agent integration config not rendered"`, `"Fleet Server host misconfigured"`, `"standalone vs fleet managed elastic agent"`.

## Diagnostic Steps

### 1. Effective Policy on Host
```bash
elastic-agent inspect
# Or
elastic-agent inspect --output yaml | head -100
```
Compare with the policy shown in Fleet UI for this agent. Any difference = policy not yet applied.

### 2. Policy Not Updating
```bash
grep -E "policy|config.*update|apply|revision" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -30
```
- Policy updates require successful check-ins. If agent is offline, updates queue.
- Confirm agent is online in Fleet UI.
- Check check-in frequency: Fleet → Settings → Agent check-in settings.

### 3. Wrong Policy Assigned
In Kibana: Fleet → Agents → select agent → Policy tab.
To reassign policy: select agents → Actions → Assign to new policy.
```bash
# Confirm from agent side what policy it thinks it has
elastic-agent inspect --output json | jq '.agent.policy_id'
```

### 4. Integration Config Not Rendered
```bash
elastic-agent inspect --output yaml | grep -A10 "<integration_name>"
```
If integration is not showing: check if the integration is correctly added in Fleet → Policies → select policy → Integrations.
Missing variables = template not filled; check for required fields in the integration config.

### 5. Output Settings
```bash
elastic-agent inspect --output yaml | grep -A20 "^outputs:"
```
Wrong Elasticsearch hosts, API key, or TLS settings in the output block = data not reaching ES.
Compare with Fleet → Settings → Outputs.

### 6. Fleet Server Host Misconfiguration
```bash
grep -E "fleet.*server.*url|fleet.server" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -10
elastic-agent inspect --output yaml | grep -A5 "fleet:"
```
In Kibana: Fleet → Settings → Fleet Server Hosts — verify URL is reachable from agent hosts.
Default Fleet Server host issues: if the default host is wrong, all newly enrolled agents use the wrong URL.

### 7. Standalone vs Fleet-Managed
Standalone: agent uses local `elastic-agent.yml`; does NOT check in to Fleet.
Fleet-managed: agent uses policy from Fleet Server; local YAML is ignored (except for initial bootstrap).
```bash
cat /opt/Elastic/Agent/elastic-agent.yml | grep -E "fleet|management"
```
`fleet.enabled: true` = fleet-managed. `fleet.enabled: false` = standalone.

### 8. Policy Conflicts
Multiple policies with overlapping integrations on the same host → resource contention.
One agent = one policy. To run multiple policies, use multiple agents (not recommended for most cases).
Check: Fleet → Policies → look for duplicate integrations that may conflict.

### 9. Config Rendering Debug
```bash
elastic-agent inspect --output yaml 2>&1 | python3 -c "import sys,yaml; yaml.safe_load(sys.stdin)" && echo "YAML valid" || echo "YAML invalid"
```

### 10. KCS + Docs Lookup
Execute retrieval protocol now with the policy issue type and integration name.

## Token Budget
- `elastic-agent inspect` gives the full effective config — use `grep` / `head` to extract relevant sections.
- Never load full NDJSON logs without a `grep` filter first.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
