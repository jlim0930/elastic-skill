---
name: apm-tls-ssl
description: Diagnoses APM Server TLS/SSL failures including certificate trust errors from APM agents, expired certificates, SAN mismatch, mutual TLS configuration, and APM Server-to-Elasticsearch TLS issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# APM Server — TLS/SSL Sub-Agent

Scope: APM agent TLS handshake failures, x509 unknown CA from agents, SAN mismatch, expired certificates, mutual TLS between agents and APM Server, APM Server→ES TLS issues.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"APM agent x509 certificate unknown authority"`, `"APM Server TLS certificate expired"`, `"APM agent SSL verify failed"`, `"APM mutual TLS"`, `"APM Server elasticsearch TLS"`.

## Diagnostic Steps

### 1. TLS Errors in APM Server Logs
```bash
grep -E "x509|tls|ssl|certificate|handshake|unknown.*authority|expired" \
  /var/log/apm-server/apm-server | tail -20
```
Key patterns:
- `x509: certificate signed by unknown authority` = agent's system CA store doesn't trust APM Server's CA
- `x509: certificate has expired` = APM Server cert is expired
- `x509: certificate is valid for X, not Y` = SAN mismatch

### 2. APM Server TLS Config
```bash
grep -A20 "ssl:" /etc/apm-server/apm-server.yml 2>/dev/null | head -25
```
```yaml
apm-server:
  ssl:
    enabled: true
    certificate: /etc/apm-server/certs/apm-server.crt
    key: /etc/apm-server/certs/apm-server.key
    certificate_authorities: ["/etc/apm-server/certs/ca.crt"]
    client_authentication: required   # for mTLS
```

### 3. Verify APM Server Certificate
```bash
openssl s_client -connect <apm-server>:8200 -servername <apm-server> 2>/dev/null \
  | openssl x509 -noout -text \
  | grep -E "Subject:|Issuer:|Not.*After|DNS:|IP Address"
```
Check:
1. Not expired (`Not After`)
2. SAN matches the hostname agents use to connect
3. Issuer is the CA that agents trust

### 4. Agent TLS Configuration by Language

**Java agent:**
```bash
# Add to JVM args
-Delastic.apm.server_url=https://<apm-server>:8200
-Delastic.apm.server_cert=/path/to/ca.crt  # or disable: -Delastic.apm.verify_server_cert=false
```

**Node.js agent:**
```javascript
require('elastic-apm-node').start({
  serverUrl: 'https://<apm-server>:8200',
  serverCaCertFile: '/path/to/ca.crt'
})
```

**Python agent:**
```ini
[elasticapm]
SERVER_URL = https://<apm-server>:8200
SERVER_CERT = /path/to/ca.crt
```

### 5. Disable TLS Verification (Debug Only)
```bash
# Temporarily disable to confirm TLS is the cause
# Java: -Delastic.apm.verify_server_cert=false
# Python: ELASTIC_APM_VERIFY_SERVER_CERT=false
# Node: process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'  (DANGEROUS — test only)
```
If connectivity works with TLS disabled, the cert/CA is the issue. Fix the cert — don't run without verification in production.

### 6. Mutual TLS (Client Certs from Agents)
For mTLS, agents must present a client certificate:
```yaml
# apm-server.yml
apm-server:
  ssl:
    client_authentication: required
    certificate_authorities: ["/etc/apm-server/certs/client-ca.crt"]
```
Agents need:
- Client certificate signed by `client-ca.crt`
- Private key corresponding to the client cert

### 7. APM Server → Elasticsearch TLS
```bash
grep -A20 "output.elasticsearch:" /etc/apm-server/apm-server.yml 2>/dev/null | grep -A10 "ssl:"
```
```bash
# Test ES TLS from APM Server host
openssl s_client -connect <es-host>:9200 -CAfile /etc/apm-server/certs/es-ca.crt \
  -servername <es-host> 2>/dev/null | grep -E "Verify return code"
```

### 8. Fleet-Managed APM TLS
Fleet-managed APM Server certificates are configured in the APM integration policy in Kibana.
```bash
# Check if APM integration has TLS configured
grep -E "ssl\|tls\|certificate" /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson \
  | grep -i "apm" | tail -10
```

### 9. Certificate Rotation
After rotating certs on APM Server:
```bash
systemctl reload apm-server  # if standalone
# Fleet-managed: update cert in Fleet APM integration policy, agent will reload
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with APM agent language, APM Server version, and TLS error.

## Token Budget
- `openssl s_client` gives instant cert chain inspection.
- `grep` for x509/tls/cert in APM Server logs.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
