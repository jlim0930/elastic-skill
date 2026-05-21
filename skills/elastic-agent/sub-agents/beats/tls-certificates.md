---
name: beats-tls-certificates
description: Diagnoses Beats TLS/SSL certificate failures including x509 unknown CA, certificate expired, SAN mismatch, mutual TLS configuration, keystore/certificate file errors, and certificate rotation issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Beats — TLS & Certificates Sub-Agent

Scope: x509 unknown CA, expired certificates, SAN mismatch, mutual TLS (mTLS) for ES/Logstash output, certificate file permission errors, keystore certificate issues, certificate rotation.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"filebeat x509 certificate unknown authority"`, `"beats TLS certificate expired"`, `"beats SSL SAN mismatch"`, `"filebeat mutual TLS"`, `"beats certificate configuration"`.

## Diagnostic Steps

### 1. TLS Errors in Beat Logs
```bash
grep -E "x509|certificate|tls|ssl|handshake|unknown.*authority|cert.*expired|SAN|verify" \
  /var/log/filebeat/filebeat | tail -20
```
Key error patterns:
- `x509: certificate signed by unknown authority` = CA cert not trusted by Beat
- `x509: certificate has expired` = server cert expired
- `x509: certificate is valid for X, not Y` = SAN mismatch (hostname doesn't match cert)
- `tls: failed to verify certificate` = general TLS handshake failure

### 2. Beat TLS Configuration
```bash
grep -A20 "ssl:" /etc/filebeat/filebeat.yml 2>/dev/null | head -25
```
Typical Elasticsearch output TLS config:
```yaml
output.elasticsearch:
  hosts: ["https://es-host:9200"]
  ssl:
    certificate_authorities: ["/etc/filebeat/certs/ca.crt"]
    certificate: "/etc/filebeat/certs/client.crt"   # for mTLS
    key: "/etc/filebeat/certs/client.key"           # for mTLS
    verification_mode: full   # full | strict | certificate | none
```

### 3. Verify Server Certificate
```bash
# Test the TLS handshake to the output endpoint
openssl s_client -connect <es-host>:9200 -CAfile /etc/filebeat/certs/ca.crt \
  -servername <es-host> 2>/dev/null | openssl x509 -noout -text \
  | grep -E "Subject:|Issuer:|Not.*After|DNS:|IP Address"
```
Check:
1. Certificate not expired (`Not After`)
2. SAN includes the hostname being connected to (`DNS:` or `IP Address:`)
3. Issuer matches the CA in Beat's config

### 4. CA Certificate Chain
```bash
# Verify CA cert
openssl x509 -in /etc/filebeat/certs/ca.crt -noout -text | grep -E "Subject:|Issuer:|Not.*After"

# Test chain validation
openssl verify -CAfile /etc/filebeat/certs/ca.crt /etc/filebeat/certs/server.crt 2>/dev/null
```
If intermediate CAs are used, the `certificate_authorities` must include the full chain, or use a bundle file.

### 5. Certificate File Permissions
```bash
ls -la /etc/filebeat/certs/
# Beat process user must be able to read these files
stat /etc/filebeat/certs/client.key | grep -E "Uid|Gid|Access:"
```
Private key should be readable only by the Beat user (e.g., `600` or `640`).
Config file strict permission check can cause Beat to reject world-readable cert files.

### 6. Mutual TLS (mTLS) for Logstash Input
On Logstash side:
```yaml
# logstash Beats input with mTLS
input {
  beats {
    ssl => true
    ssl_certificate_authorities => ["/etc/logstash/certs/ca.crt"]
    ssl_certificate => "/etc/logstash/certs/server.crt"
    ssl_key => "/etc/logstash/certs/server.key"
    ssl_verify_mode => "force_peer"
  }
}
```
On Filebeat side, both `certificate` and `key` must be set in the `ssl` block under the Logstash output.

### 7. Verification Mode
```yaml
ssl:
  verification_mode: full      # Verify hostname + cert chain (recommended)
  verification_mode: certificate  # Verify cert chain only (skip hostname)
  verification_mode: none      # Disable TLS verification (insecure, for debugging only)
```
Use `none` only temporarily to confirm TLS is the cause, then fix the cert issue.

### 8. Certificate Rotation
After rotating certificates:
1. Update cert files on disk
2. Reload Beat (SIGHUP or service restart — Beat doesn't hot-reload certs)
```bash
systemctl reload filebeat || kill -HUP $(pgrep -f filebeat)
```

### 9. Logstash Beats Input TLS
```bash
grep -E "ssl.*error|tls.*error|certificate" /var/log/logstash/logstash-plain.log | tail -10
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the exact TLS error message and Beat version.

## Token Budget
- `openssl s_client` gives instant cert chain and SAN verification.
- `grep` for x509/tls in Beat logs before reading full config.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
