---
name: cross-enrollment-bootstrap
description: Diagnoses cross-component enrollment and bootstrap failures spanning Elastic Agent, Fleet Server, and Kibana including Fleet Server not ready at enrollment time, Kibana Fleet setup not complete, and multi-component bootstrap sequencing issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Cross-Component — Enrollment & Bootstrap Sub-Agent

Scope: Multi-component enrollment failures, Fleet Server not ready when agents try to enroll, Kibana Fleet setup incomplete, bootstrap order issues, agent enrollment in complex topologies (air-gapped, multi-cluster).

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Fleet Server not ready enrollment"`, `"Kibana Fleet setup incomplete"`, `"Elastic Agent enrollment bootstrap"`, `"Fleet Server Elasticsearch not ready"`, `"agent enrollment complex topology"`.

## Diagnostic Steps

### 1. Bootstrap Order Verification
Correct startup order for a fresh Fleet deployment:
1. Elasticsearch (must be healthy and reachable)
2. Kibana (wait for it to fully start — check `/api/status`)
3. Fleet setup in Kibana (creates `.fleet-*` indices and policies)
4. Fleet Server (first Elastic Agent enrolled with `--fleet-server-*` flags)
5. Additional Elastic Agents

```bash
# Verify ES is ready
curl -s http://localhost:9200/_cluster/health | jq '{status:.status, nodes:.number_of_nodes}'

# Verify Kibana is ready and Fleet is set up
curl -s http://localhost:5601/api/status | jq '{level:.status.overall.level}'
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/setup" | jq '.isInitialized'
```

### 2. Fleet Setup Status
```bash
# Check if Fleet is initialized
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/setup" | jq '.'

# If not initialized, run setup
curl -s -u <user>:<pass> -X POST "http://localhost:5601/api/fleet/setup" \
  -H "kbn-xsrf: true" | jq '.'
```
Fleet must be initialized before Fleet Server can register. If Kibana is not set up, Fleet Server enrollment fails.

### 3. Fleet Server Bootstrap
```bash
# Bootstrap Fleet Server (first-time)
elastic-agent install \
  --url=https://<kibana-host>:5601 \
  --fleet-server-es=https://<es-host>:9200 \
  --fleet-server-service-token=<service-token> \
  --fleet-server-policy=<policy-id> \
  --certificate-authorities=/path/to/ca.crt \
  --fleet-server-es-ca=/path/to/es-ca.crt \
  --fleet-server-cert=/path/to/fleet-server.crt \
  --fleet-server-cert-key=/path/to/fleet-server.key
```

Check Fleet Server startup:
```bash
grep '"level":"error"' /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson \
  | tail -20
curl -s https://localhost:8220/api/status | jq '.status'
```

### 4. Service Token for Fleet Server
```bash
# Generate service token if missing
curl -s -u elastic:<pass> -X POST \
  "http://localhost:9200/_security/service/elastic/fleet-server/credential/token/fleet-server-token" \
  | jq '{token:.token.value}'
```
Service token must be generated before Fleet Server can authenticate to ES.

### 5. Enrollment Token
```bash
# List enrollment tokens
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/enrollment_api_keys" \
  | jq '.items[] | {id:.id, name:.name, policy_id:.policy_id, active:.active}'
```
If token is expired or belongs to a deleted policy, enrollment fails.
Create a new enrollment token:
```bash
curl -s -u <user>:<pass> -X POST "http://localhost:5601/api/fleet/enrollment_api_keys" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{"policy_id":"<policy-id>"}' | jq '{api_key:.item.api_key}'
```

### 6. Multi-Cluster / Remote ES Bootstrap
If Fleet Server connects to a remote ES cluster:
```bash
# Test ES connectivity from Fleet Server host
curl -s https://<remote-es>:9200/_cluster/health \
  --cacert /path/to/es-ca.crt | jq '.status'
```

### 7. Air-Gapped Enrollment
In air-gapped environments, agents need local artifact registry:
```bash
elastic-agent install \
  --url=https://<fleet-server>:8220 \
  --enrollment-token=<token> \
  --certificate-authorities=/path/to/ca.crt \
  --proxy-disabled  # skip proxy for local Fleet Server
```

### 8. KCS + Docs Lookup
Execute retrieval protocol with the specific bootstrap component and error message.

## Token Budget
- Check ES health + Fleet initialization status before reading any logs.
- `grep` for enrollment errors in agent logs.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
