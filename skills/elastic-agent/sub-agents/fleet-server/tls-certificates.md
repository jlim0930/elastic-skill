---
name: fleet-server-tls-certificates
description: Diagnoses Fleet Server certificate trust failures, missing CA on agents, SAN mismatch for Fleet Server URL, reverse proxy TLS termination issues, mTLS/client auth problems, and expired or rotated certs not propagated to agents.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Fleet Server — TLS / Certificates Sub-Agent

Scope: Fleet Server certificate trust failures, missing CA on agents, SAN mismatch for Fleet Server URL, reverse proxy TLS termination, mTLS/client auth problems, expired/rotated certs not propagated.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Fleet Server TLS certificate trust failure"`, `"Fleet Server CA missing agents"`, `"Fleet Server SAN mismatch"`, `"Fleet Server reverse proxy TLS"`, `"Fleet Server cert rotation"`.

## Diagnostic Steps

### 1. TLS Errors
```bash
grep -E "x509|certificate|TLS|SSL|handshake|SAN|CA" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -30
```
Key patterns:
- `x509: certificate signed by unknown authority` → agent does not trust Fleet Server CA.
- `x509: cannot validate certificate for <IP>` → cert has no IP SAN; use hostname.
- `x509: certificate has expired` → Fleet Server cert expired.

### 2. Fleet Server Certificate Check
```bash
openssl s_client -connect <fleet-server-host>:8220 </dev/null 2>/dev/null \
  | openssl x509 -noout -dates -subject -issuer
openssl s_client -connect <fleet-server-host>:8220 </dev/null 2>/dev/null \
  | openssl x509 -noout -text | grep -A5 "Subject Alternative"
```
Verify:
- Cert is not expired.
- SAN includes the hostname/IP used in enrollment `--url`.
- Issuer CA matches the CA distributed to agents.

### 3. CA Distribution to Agents
Agents trust the CA provided at enrollment:
```bash
elastic-agent inspect --output yaml | grep -A5 "ssl:" | grep certificate_authorities
```
If Fleet Server cert is rotated and CA changes, all agents need to be re-enrolled with the new CA.
During enrollment:
```bash
elastic-agent enroll --url https://<fleet-server>:8220 \
  --enrollment-token <token> \
  --certificate-authorities /path/to/ca.crt
```

### 4. Fleet Server Cert Config
```bash
elastic-agent inspect --output yaml | grep -A10 "fleet.server:"
# Or check install arguments
grep -E "fleet-server-cert|fleet-server-cert-key|fleet-server-es-ca" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | head -5
```

### 5. Reverse Proxy TLS Termination
If a reverse proxy terminates TLS before Fleet Server:
- Proxy presents its own cert to agents (agents must trust proxy CA).
- Fleet Server can run with or without TLS behind the proxy.
- Proxy must forward the original `Host` header and connection upgrade headers.
```bash
# Check what cert the proxy presents
openssl s_client -connect <proxy-host>:8220 </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer
```

### 6. mTLS / Client Auth
If Fleet Server requires client certs from agents:
```bash
grep -E "client.*auth|mutual.*tls|verify.*peer" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -10
```
Agent presents the cert configured in `ssl.certificate` + `ssl.key` in the agent config.

### 7. Certificate Rotation Propagation
After rotating Fleet Server cert:
1. Update Fleet Server install with new cert (restart required).
2. Update Fleet → Settings to distribute new CA to agents via policy.
3. Agents will download new CA on next check-in (before old cert expires).
4. If old cert is already expired, agents need manual re-enrollment.

### 8. KCS + Docs Lookup
Execute retrieval protocol now with the x509 error and whether it's during enrollment or check-in.

## Token Budget
- `openssl s_client` cert check is always first — tells you expiry, SANs, and CA in one command.
- `grep` for x509/TLS keywords before reading full agent logs.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
