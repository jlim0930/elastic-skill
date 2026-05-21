---
name: cross-certificates-tls
description: Diagnoses cross-component TLS and certificate issues spanning Elastic Agent, Fleet Server, Beats, and APM Server including CA trust chain failures, certificate rotation across components, SAN validation, and generating or converting certificates for the Elastic stack.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Cross-Component — Certificates & TLS Sub-Agent

Scope: CA trust chain failures across components, SAN validation, certificate rotation procedures affecting multiple components, PEM/PKCS#12 conversion, self-signed vs CA-signed, Elastic Stack certificate generation.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Elastic Stack TLS certificate configuration"`, `"Elastic Agent Fleet Server certificate trust"`, `"Elastic certificates x509 unknown authority"`, `"elasticsearch-certutil generate certificates"`, `"Elastic Stack PKI setup"`.

## Diagnostic Steps

### 1. Certificate Error Triage
```bash
# Elastic Agent
grep -E "x509|certificate|tls|ssl|handshake" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -20

# Fleet Server (same as Agent)
grep '"level":"error"' /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson \
  | grep -E "x509|cert|tls" | tail -10

# Beats
grep -E "x509|certificate|tls|handshake" /var/log/filebeat/filebeat | tail -10

# APM Server
grep -E "x509|certificate|tls|handshake" /var/log/apm-server/apm-server | tail -10
```

### 2. Inspect Certificate Chain
```bash
# Inspect certificate for any endpoint
openssl s_client -connect <host>:<port> -servername <host> 2>/dev/null \
  | openssl x509 -noout -text \
  | grep -E "Subject:|Issuer:|Not.*After|DNS:|IP Address:"

# Port reference
# ES: 9200 | Fleet Server: 8220 | Kibana: 5601 | APM: 8200 | Logstash Beats: 5044
```

### 3. CA Certificate Distribution
All components that need to trust each other must have access to the CA cert.
```bash
# Check CA cert on each component host
ls -la /etc/elastic/certs/ca.crt 2>/dev/null
ls -la /etc/filebeat/certs/ca.crt 2>/dev/null
ls -la /opt/Elastic/Agent/data/elastic-agent-*/certs/ 2>/dev/null | head -5
```

### 4. Generate Certificates with elasticsearch-certutil
```bash
# 1. Generate CA
elasticsearch-certutil ca --out /tmp/elastic-stack-ca.p12 --pass ""

# 2. Generate node/component certs signed by the CA
elasticsearch-certutil cert --ca /tmp/elastic-stack-ca.p12 --pass "" \
  --name fleet-server --dns fleet-server.example.com --ip 10.0.0.5 \
  --out /tmp/fleet-server.p12

# 3. Convert to PEM for Beats/Agent
openssl pkcs12 -in /tmp/fleet-server.p12 -out /tmp/fleet-server.crt -clcerts -nokeys -passin pass:""
openssl pkcs12 -in /tmp/fleet-server.p12 -out /tmp/fleet-server.key -nocerts -nodes -passin pass:""
openssl pkcs12 -in /tmp/elastic-stack-ca.p12 -out /tmp/ca.crt -cacerts -nokeys -passin pass:""
```

### 5. SAN Validation
Every component certificate must include SANs for how clients connect:
```bash
# Check SAN in existing cert
openssl x509 -in /etc/elastic/certs/fleet-server.crt -noout -text \
  | grep -A3 "Subject Alternative Name"
```
- DNS names: use all hostnames clients will use (FQDN, short name, load balancer name)
- IP addresses: include all IPs if clients connect by IP

### 6. Certificate File Format Conversion
```bash
# PEM cert + key → PKCS#12
openssl pkcs12 -export -in cert.crt -inkey cert.key -out cert.p12 -passout pass:""

# PKCS#12 → PEM cert
openssl pkcs12 -in cert.p12 -clcerts -nokeys -out cert.crt -passin pass:""

# PKCS#12 → PEM key
openssl pkcs12 -in cert.p12 -nocerts -nodes -out cert.key -passin pass:""

# DER → PEM
openssl x509 -inform der -in cert.der -out cert.pem
```

### 7. Certificate Rotation Across Components
When rotating the CA or component certs:
1. Add the new CA to all trust stores (before replacing old cert)
2. Deploy new component certs (signed by new CA)
3. Remove old CA from trust stores
4. Restart all components in order: ES → Kibana → Fleet Server → Agents → Beats → APM

```bash
# Verify cert is within 30 days of expiry
openssl x509 -in /etc/elastic/certs/fleet-server.crt -noout -checkend 2592000 \
  && echo "OK - more than 30 days" || echo "WARNING - expires within 30 days"
```

### 8. Elastic Agent Certificate Trust
Elastic Agent uses the OS trust store or explicitly configured CAs:
```bash
grep -r "certificate_authorities\|ca_trusted_fingerprint" \
  /opt/Elastic/Agent/data/elastic-agent-*/inputs.d/ 2>/dev/null | head -10
```
The `ca_trusted_fingerprint` option (SHA-256 of CA cert) is an alternative to distributing the full CA cert file.

### 9. KCS + Docs Lookup
Execute retrieval protocol with the specific component pair (agent→fleet-server, beats→ES, etc.) and certificate error.

## Token Budget
- `openssl s_client` gives instant cert chain inspection — run before any log analysis.
- Check expiry with `openssl x509 -checkend` across all component certs.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
