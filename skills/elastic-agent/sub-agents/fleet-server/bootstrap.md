---
name: fleet-server-bootstrap
description: Diagnoses Fleet Server fails to start, bootstrap/install command errors, service token problems, Fleet Server not registering correctly in Kibana, policy assignment during bootstrap, on-prem setup mistakes, and single-node bootstrap confusion.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Fleet Server — Bootstrap Sub-Agent

Scope: Fleet Server fails to start, bootstrap/install command errors, service token problems, Fleet Server not registering in Kibana, policy assignment during bootstrap, on-prem setup mistakes, single-node bootstrap confusion.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Fleet Server bootstrap failed"`, `"Fleet Server service token invalid"`, `"Fleet Server not registering Kibana"`, `"Fleet Server on-prem setup"`, `"Fleet Server single node bootstrap"`.

## Diagnostic Steps

### 1. Bootstrap Errors
```bash
grep -E "error|failed|bootstrap|service.token|fleet.server" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -40
```
Key patterns:
- `failed to bootstrap Fleet Server` → service token or ES connectivity issue.
- `service token is invalid` → token was invalidated or copied incorrectly.
- `failed to connect to Elasticsearch` → ES host/TLS config wrong during bootstrap.

### 2. Bootstrap Command Syntax
Correct bootstrap command for on-prem:
```bash
elastic-agent install \
  --fleet-server-es=https://<es-host>:9200 \
  --fleet-server-service-token=<service-token> \
  --fleet-server-policy=<policy-id> \
  --fleet-server-es-ca=/path/to/ca.crt \
  --fleet-server-cert=/path/to/fleet-server.crt \
  --fleet-server-cert-key=/path/to/fleet-server.key \
  --certificate-authorities=/path/to/ca.crt
```
Verify each option is provided and paths exist.

### 3. Service Token Validation
```bash
# Generate new service token
curl -s -u <user>:<pass> -X POST "http://localhost:9200/_security/service/elastic/fleet-server/credential/token/<token_name>" \
  | jq '{token:.token.value}'

# Verify existing tokens
curl -s -u <user>:<pass> "http://localhost:9200/_security/service/elastic/fleet-server/credential" \
  | jq '.tokens | keys'
```
Service token grants Fleet Server access to ES. If invalid, Fleet Server cannot start.

### 4. ES Connectivity from Fleet Server Host
```bash
curl -v --cacert /path/to/ca.crt https://<es-host>:9200/_cluster/health
nc -zv <es-host> 9200
```
Fleet Server must reach ES on port 9200 before bootstrap can complete.

### 5. Fleet Server Policy
Fleet Server requires a Fleet Server policy type, not a regular agent policy.
In Kibana: Fleet → Settings → check "Fleet Server hosts" section.
If no policy exists, create one: Fleet → Policies → Create agent policy → "Fleet Server" type.
```bash
elastic-agent inspect --output yaml | grep -A5 "fleet.server"
```

### 6. Registration in Kibana
After successful bootstrap, Fleet Server should appear in: Fleet → Settings → Fleet Server Hosts.
```bash
curl -s -u <user>:<pass> "http://localhost:5601/api/fleet/fleet_server_hosts" | jq '.items[] | {id:.id, host_urls:.host_urls, is_default:.is_default}'
```
Not registered = bootstrap failed silently. Check ES logs for Fleet Server write errors.

### 7. Single-Node Bootstrap
On a single host (ES + Kibana + Fleet Server):
```bash
elastic-agent install \
  --fleet-server-es=https://localhost:9200 \
  --fleet-server-service-token=<token> \
  --fleet-server-cert=/path/to/fleet-server.crt \
  --fleet-server-cert-key=/path/to/fleet-server.key
```
`localhost` in `--fleet-server-es` is valid here. Use the machine's actual hostname or IP in `--url` for agent enrollment.

### 8. On-Prem Common Mistakes
- Using HTTP instead of HTTPS for ES endpoint when TLS is enabled.
- Missing `--fleet-server-es-ca` when ES uses a custom CA.
- Policy ID that doesn't exist or is the wrong type.
- Service token generated for wrong ES cluster.

### 9. KCS + Docs Lookup
Execute retrieval protocol now with the bootstrap error message.

## Token Budget
- `grep` for bootstrap/service-token keywords in logs before reading full log files.
- Service token check via ES API is faster than log analysis.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
