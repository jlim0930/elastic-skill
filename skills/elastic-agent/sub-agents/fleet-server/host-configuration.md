---
name: fleet-server-host-configuration
description: Diagnoses wrong Fleet Server URL configured, default Fleet Server host misconfigured, host URL changed causing agents to stop checking in, public vs internal URL mismatch, multiple Fleet Servers with wrong routing, and load balancer target issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Fleet Server — Host Configuration Sub-Agent

Scope: wrong Fleet Server URL configured, default Fleet Server host misconfigured, host URL changed and agents stop checking in, public URL vs internal URL mismatch, multiple Fleet Servers with wrong routing, load balancer target issues.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Fleet Server URL misconfigured"`, `"Fleet Server default host wrong"`, `"Fleet Server URL changed agents offline"`, `"multiple Fleet Servers routing"`, `"Fleet Server load balancer URL"`.

## Diagnostic Steps

### 1. Current Fleet Server Host Configuration
```bash
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/fleet_server_hosts" \
  | jq '.items[] | {id:.id, name:.name, host_urls:.host_urls, is_default:.is_default}'
```
The "default" Fleet Server host is what new enrollments use unless overridden in the enrollment command.

### 2. Agent's Configured Fleet Server URL
```bash
elastic-agent inspect --output yaml | grep -A5 "fleet:"
grep -E "fleet.*url|fleet.*host" /opt/Elastic/Agent/elastic-agent.yml 2>/dev/null | head -5
```
The agent's enrolled Fleet Server URL is stored in its state. After enrollment, URL changes in Fleet UI don't automatically update existing enrolled agents' targets.

### 3. URL Changed After Enrollment
Agents track the Fleet Server URL at enrollment time. If the URL changes:
```bash
grep -E "connection.*refused|no such host|fleet.*url" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -20
```
Fix: re-enroll agents with the new URL, or add the new URL as an additional Fleet Server host (agents will discover it via policy).

### 4. Public vs Internal URL Mismatch
Common in cloud/NAT environments:
- Fleet UI configured with internal IP → external agents cannot reach it.
- Fleet UI configured with public FQDN → internal agents use external routing (inefficient or blocked).

Check what agents are configured to reach:
```bash
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/settings" | jq '.item.fleet_server_hosts'
```
Solution: configure separate Fleet Server host entries for internal and external agents, and use separate enrollment tokens tied to the appropriate policies.

### 5. Multiple Fleet Servers / Wrong Routing
```bash
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/fleet_server_hosts" | jq '.items[] | {name:.name, urls:.host_urls, default:.is_default}'
```
Agents enroll to the default host unless a specific host is specified in the enrollment command.
If multiple Fleet Servers exist, each agent should be enrolled to the one it can reach.

### 6. Load Balancer Target
If a load balancer fronts Fleet Server:
```bash
# Check what's behind the LB
curl -v https://<lb-host>:8220/api/status 2>&1 | grep -E "Connected|HTTP|status"
```
LB health check must hit `/api/status` (returns 200 when Fleet Server is healthy).
LB must support HTTP/2 or long-lived HTTP/1.1 connections (agent check-ins are long-polling).
Timeout: LB idle connection timeout must be ≥ 90 seconds.

### 7. Fleet Server Self-URL
Fleet Server must know its own public URL for enrollment validation.
Set via `--fleet-server-host` during installation or via Fleet → Settings → Fleet Server Hosts.
```bash
elastic-agent inspect --output yaml | grep -E "server.host|fleet_server_host"
```

### 8. Updating Default Fleet Server Host
In Kibana: Fleet → Settings → Fleet Server Hosts → select host → set as default.
Existing agents do NOT update their target automatically — they use the URL from their enrollment state.
```bash
# Bulk re-enrollment (for small fleets)
# Generate new enrollment token for updated policy
curl -s -u <user>:<pass> -X POST "http://localhost:5601/api/fleet/enrollment_api_keys" \
  -H 'kbn-xsrf: true' -H 'Content-Type: application/json' \
  -d '{"policy_id": "<policy_id>"}' | jq '.item.api_key'
```

### 9. KCS + Docs Lookup
Execute retrieval protocol now with the URL mismatch type and agent count affected.

## Token Budget
- Fleet host config API gives instant configuration state — run before log analysis.
- `grep` for URL/host errors in agent logs — never read full NDJSON logs.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
