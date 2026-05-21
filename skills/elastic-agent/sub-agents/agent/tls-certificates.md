---
name: agent-tls-certificates
description: Diagnoses Elastic Agent unknown CA errors, SAN mismatch, expired certificates, Fleet Server cert trust issues, Elasticsearch output TLS failures, mutual TLS/client cert issues, PEM/PKCS#12 config mistakes, and hostname vs IP certificate validation problems.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Elastic Agent — TLS / Certificates Sub-Agent

Scope: unknown CA, SAN mismatch, expired certificates, Fleet Server cert trust issues, Elasticsearch output TLS failures, mutual TLS/client cert, PEM/PKCS#12 path/config mistakes, hostname vs IP cert validation.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"elastic-agent x509 certificate unknown authority"`, `"elastic-agent SAN mismatch"`, `"elastic-agent TLS certificate expired"`, `"elastic-agent Fleet Server cert trust"`, `"elastic-agent mutual TLS client cert"`.

## Diagnostic Steps

### 1. TLS Error Identification
```bash
grep -E "x509|certificate|TLS|SSL|handshake|SAN|IP.*SAN" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -30
```
Key error patterns:
- `x509: certificate signed by unknown authority` → CA not trusted by agent.
- `x509: cannot validate certificate for <IP> because it doesn't contain any IP SANs` → cert has no IP SAN; use DNS hostname.
- `x509: certificate has expired or is not yet valid` → cert expired or clock skew.
- `tls: failed to verify certificate` → general verification failure.

### 2. Certificate Expiry Check
```bash
# Fleet Server cert
openssl s_client -connect <fleet-server>:8220 </dev/null 2>/dev/null | openssl x509 -noout -dates

# ES output cert
openssl s_client -connect <es-host>:9200 </dev/null 2>/dev/null | openssl x509 -noout -dates
```

### 3. SAN Verification
```bash
openssl s_client -connect <fleet-server>:8220 </dev/null 2>/dev/null | openssl x509 -noout -text | grep -A5 "Subject Alternative"
```
- If using IP in `--url`: cert must have IP SAN (e.g., `IP Address:10.0.0.1`).
- If using hostname: cert must have DNS SAN (e.g., `DNS:fleet-server.example.com`).
- IP-only access with DNS-SAN-only cert = `cannot validate certificate ... IP SANs` error.
- Fix: use hostname in enrollment URL, or regenerate cert with IP SAN.

### 4. CA Trust for Fleet Server
```bash
# Pass CA during enrollment
elastic-agent enroll \
  --url https://<fleet-server>:8220 \
  --enrollment-token <token> \
  --certificate-authorities /path/to/ca.crt

# Or set in agent config for ongoing trust
elastic-agent inspect --output yaml | grep -A5 "ssl:"
```

### 5. ES Output TLS Failures
```bash
grep -E "certificate|TLS|ssl.*output" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/filebeat-*.ndjson 2>/dev/null | tail -20
```
```bash
elastic-agent inspect --output yaml | grep -A10 "^outputs:" | grep -A5 "ssl:"
```
The ES output's `ssl.certificate_authorities` must include the ES CA cert.

### 6. Mutual TLS (mTLS)
Agent presenting client cert to Fleet Server or ES:
```bash
elastic-agent inspect --output yaml | grep -E "certificate:|key:|certificate_authorities:"
```
`certificate` + `key` = client cert. `certificate_authorities` = trusted CAs.
Client cert must be signed by a CA trusted by the server.

### 7. PEM / PKCS#12 Config
Agent accepts PEM paths:
```yaml
ssl:
  certificate_authorities: ["/path/to/ca.crt"]
  certificate: "/path/to/client.crt"
  key: "/path/to/client.key"
```
For PKCS#12 (Beats-based inputs): convert to PEM first using `openssl pkcs12`.
```bash
openssl pkcs12 -in keystore.p12 -cacerts -nokeys -chain -out ca.crt
openssl pkcs12 -in keystore.p12 -clcerts -nokeys -out client.crt
openssl pkcs12 -in keystore.p12 -nocerts -nodes -out client.key
```

### 8. Fleet-Managed CA Distribution
When managing through Fleet: the agent's CA trust is set in Fleet → Settings → Advanced.
Any change to the Fleet Server TLS cert requires updating the CA in Fleet settings and propagating to agents.

### 9. KCS + Docs Lookup
Execute retrieval protocol now with the specific x509 error message and component pair.

## Token Budget
- `openssl s_client | openssl x509 -noout -dates` for expiry — fastest cert check.
- `grep` for x509/TLS keywords before reading full agent logs.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
