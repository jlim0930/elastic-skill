---
name: agent-fleet-policy
description: Diagnoses Elastic Agent Fleet policy application failures, integration configuration errors, and output routing problems.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Fleet Policy Sub-Agent

Scope: policy application failures, integration input errors, output misconfiguration, policy revision conflicts, agent not applying new policy.

## Retrieval Protocol
Follow [../../../shared/retrieval-protocol.md](../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Fleet policy application failed elastic-agent"`, `"integration input error elastic-agent"`, `"Fleet output configuration Elasticsearch"`.

## Diagnostic Steps

### 1. Policy Application Status
In Kibana: Fleet → Agents → select agent → check **Policy revision**.
If the agent's revision is behind the current policy revision, the policy has not been applied.
Check agent logs for policy application errors:
```bash
grep -E "policy|configuration|apply|failed|error" /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | grep -i "policy\|revision" | tail -50
```

### 2. Output Configuration
Fleet → Settings → Outputs → verify the output (Elasticsearch or Logstash) is configured correctly.
Test output connectivity from the agent:
```bash
# For Elasticsearch output:
curl -v https://<es-url>:443 -u elastic:<pass>
# For Logstash output:
nc -zv <logstash-host> 5044
```
`Failed to connect to output` in agent logs = output not reachable.

### 3. Integration Input Errors
```bash
grep -E "input.*error\|component.*failed\|harvester.*error" /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -30
```
Common integration errors:
- File input: `no such file or directory` → log path does not exist.
- Metrics input: `permission denied` → agent lacks read access to the metrics source.
- Network input: `address already in use` → port conflict.

### 4. Component Diagnostics
Each integration runs as a managed component. List component status:
```bash
elastic-agent status
```
Any component in `FAILED` state → inspect that component's log:
```bash
ls /opt/Elastic/Agent/data/elastic-agent-*/logs/
grep -E "error|failed" /opt/Elastic/Agent/data/elastic-agent-*/logs/<component>-*.ndjson | tail -30
```

### 5. Policy Tamper / Override
If `elastic-agent.yml` was manually edited in Fleet-managed mode, the manual changes will be overwritten on next policy check-in. Do not edit `elastic-agent.yml` directly in Fleet-managed mode.

### 6. KCS + Docs Lookup
Execute retrieval protocol now. Query with the integration name and the error type.

## Token Budget
- `grep` agent and component logs for policy/error keywords; never load full NDJSON logs.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../shared/output-format.md](../../../shared/output-format.md).
Reference thresholds from [../../../shared/thresholds.md](../../../shared/thresholds.md).
