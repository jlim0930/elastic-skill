---
name: apm-agent-connectivity
description: Diagnoses APM agent connectivity failures including agents cannot reach APM Server, connection refused, secret token or API key rejection, 401/403 errors, and language-specific agent configuration issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# APM Server — Agent Connectivity Sub-Agent

Scope: APM agents cannot reach APM Server, connection refused, wrong URL, secret token/API key auth failures (401/403), agent-side configuration issues, language-specific APM agent setup.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"APM agent connection refused"`, `"APM agent 401 unauthorized"`, `"APM agent cannot connect server"`, `"APM secret token wrong"`, `"APM agent URL configuration"`.

## Diagnostic Steps

### 1. APM Server Reachability
```bash
# Test from APM agent host (replace with actual APM server host)
curl -s http://<apm-server>:8200/ 2>&1 | head -5
nc -z -w5 <apm-server> 8200 && echo "port reachable" || echo "port blocked"
```

### 2. Auth Errors in APM Server Logs
```bash
grep -E "401|403|unauthorized|forbidden|secret.*token|api.*key|auth" \
  /var/log/apm-server/apm-server | tail -20

# Fleet-managed APM
grep '"level":"error"' /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson \
  | grep -i "auth\|401\|403\|token" | tail -10
```

### 3. APM Server Auth Configuration
```bash
# Standalone
grep -E "secret_token|api_key|auth:" /etc/apm-server/apm-server.yml 2>/dev/null

# Fleet-managed: check via Kibana Fleet → Policies → APM integration settings
```
Secret token validation:
- Agent must send `Authorization: Bearer <secret_token>` header
- If server has no secret token configured, any agent can send (no auth)
- If server has secret token, agents without it get 401

### 4. API Key Authentication
```bash
# Check if API keys are enabled on APM Server
grep -E "api_key:" /etc/apm-server/apm-server.yml 2>/dev/null

# Verify API key exists in ES
curl -s -u <user>:<pass> "http://localhost:9200/_security/api_key?name=<key_name>" \
  | jq '.api_keys[] | {name:.name, invalidated:.invalidated}'
```

### 5. Agent-Side Configuration Check
Common agent configuration patterns:
```bash
# Java agent via JVM args (example)
grep -r "elastic.apm.server" /etc/app/*.properties /etc/systemd/system/*.service 2>/dev/null | head -10
# Node.js
grep -r "serverUrl\|secretToken\|apiKey" /app/config/ 2>/dev/null | head -10
# Python
grep -r "SERVER_URL\|SECRET_TOKEN" /app/elasticapm.ini 2>/dev/null 2>/dev/null
```
URL must include scheme: `http://` or `https://`. Missing scheme = agent silently fails.

### 6. Test Auth with curl
```bash
# Test without auth (should return info if auth not required)
curl -s http://<apm-server>:8200/

# Test with secret token
curl -s -H "Authorization: Bearer <secret_token>" http://<apm-server>:8200/

# Test intake with secret token
curl -s -X POST "http://<apm-server>:8200/intake/v2/events" \
  -H "Authorization: Bearer <secret_token>" \
  -H "Content-Type: application/x-ndjson" \
  -d '{}' | jq '.'
```
200 = connected and auth OK. 401 = wrong token. 403 = forbidden. 404 = wrong URL path.

### 7. Network / Firewall Between Agent and APM Server
```bash
# Outbound connectivity check from app host
curl -sv http://<apm-server>:8200/ 2>&1 | grep -E "Connected|refused|timeout|< HTTP"
traceroute <apm-server> 2>/dev/null | tail -5
```
If the APM server is in a different network segment, verify security group / firewall rules allow TCP 8200 from application hosts.

### 8. APM Server Behind a Reverse Proxy
If APM Server is behind nginx/HAProxy:
- Verify proxy passes `Authorization` header (not stripped)
- Check proxy adds correct headers for TLS termination
- Verify no request size limits on the proxy (APM payloads can be large)
```bash
curl -sv http://<proxy>:8200/ 2>&1 | grep -E "< HTTP|< Server|< X-"
```

### 9. KCS + Docs Lookup
Execute retrieval protocol with the APM agent language, APM server version, and specific error.

## Token Budget
- `curl` reachability test before log analysis.
- `grep` for 401/403/auth patterns in APM server logs.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
