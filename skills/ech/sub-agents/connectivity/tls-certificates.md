---
name: ech-tls-certificates
description: Diagnoses ECH TLS and certificate issues including certificate trust failures, invalid instance certificate alerts, proxy-cannot-validate-backend-certificate errors, unknown CA or trust chain mismatch, certificate rotation issues, expired certificates, hostname/SAN mismatch, and client trust problems for hosted endpoints.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECH — TLS & Certificates Sub-Agent

Scope: Certificate trust failures connecting to ECH endpoints, invalid instance certificate alerts, proxy/backend certificate validation errors, unknown CA / trust chain mismatch, certificate rotation issues, expired certificates, hostname/SAN mismatch, client trust configuration for hosted endpoints.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Elastic Cloud certificate trust failure"`, `"ECH x509 unknown authority"`, `"Elastic Cloud TLS certificate expired"`, `"ECH SAN mismatch certificate"`, `"Elastic Cloud certificate rotation"`, `"ECH proxy backend certificate"`.

## Diagnostic Steps

### 1. Inspect the ECH Endpoint Certificate
```bash
# Inspect the certificate served by the ECH endpoint
openssl s_client -connect <es-endpoint>:443 -servername <es-endpoint> 2>/dev/null \
  | openssl x509 -noout -text \
  | grep -E "Subject:|Issuer:|Not.*After|DNS:|IP Address:"
```
Verify:
1. **Not After**: certificate is not expired
2. **DNS:** SAN entries include the hostname being connected to
3. **Issuer**: should be a public trusted CA (DigiCert, Let's Encrypt, Amazon, etc.) for ECH endpoints

### 2. ECH Certificate Authority and Trust Chain
ECH endpoints use certificates signed by **public trusted CAs** — trusted by default in:
- OS certificate stores (macOS, Windows, most Linux distros)
- JVM cacerts (Java 8u251+ includes common CAs)
- Python certifi, Node.js, Go default trust stores

**If a client gets `x509: certificate signed by unknown authority` or `PKIX path building failed`:**
- The client is using a custom or outdated CA trust store that doesn't include the public CA
- A corporate SSL inspection proxy is replacing the ECH certificate with its own cert
- The client OS CA bundle is very old and the ECH CA is not included

```bash
# Check certificate issuer to identify who signed it
openssl s_client -connect <es-endpoint>:443 -servername <es-endpoint> 2>/dev/null \
  | openssl x509 -noout -issuer
```

### 3. Corporate SSL Inspection — Proxy Replacing the Certificate
If clients go through a corporate proxy with SSL inspection (TLS interception):
```bash
# Compare the actual cert issuer vs. what ECH serves
openssl s_client -connect <es-endpoint>:443 -servername <es-endpoint> 2>/dev/null \
  | openssl x509 -noout -subject -issuer
```

If the **Issuer** shows your corporate proxy CA (not DigiCert/Let's Encrypt): SSL inspection is intercepting the connection and replacing the ECH certificate with the proxy's certificate.

Options:
1. **Bypass SSL inspection** for `*.elastic-cloud.com` (recommended) — add an exception in the proxy policy
2. **Add the proxy CA to the client's trust store** — the client trusts the proxy CA
3. **Configure the Elastic client to use the proxy CA**: set `ssl.certificate_authorities` to point to the proxy CA cert

### 4. Proxy Cannot Validate Backend Certificate
This is a platform-side issue, not a client-side issue. It appears as a health warning in the ECH console:
`"Invalid instance certificate"` or `"Proxy cannot validate backend certificate"`

This means the ECH proxy cannot establish a valid TLS connection to the Elasticsearch backend instance:
- Backend certificate expired
- Backend certificate CA chain is broken
- Backend certificate SAN does not match the hostname the proxy uses

**This is a platform-level issue — contact Elastic Support.** Do not attempt to self-remediate backend certificate issues in ECH.

### 5. Java Client Certificate Trust
Java applications use the JVM truststore (`cacerts`):
```bash
# Check if common CAs are in JVM truststore
keytool -list -cacerts -storepass changeit | grep -iE "digicert|letsencrypt|amazon"

# If using Python, verify certifi bundle
python3 -c "import certifi; print(certifi.where())"
curl --cacert $(python3 -c "import certifi; print(certifi.where())") \
  "https://<es-endpoint>/_cluster/health"
```

If JVM truststore lacks the ECH CA: update JVM or import the CA:
```bash
# Import corporate proxy CA if SSL inspection is in use
keytool -import -trustcacerts -keystore $JAVA_HOME/lib/security/cacerts \
  -storepass changeit -alias corporate-proxy-ca -file /path/to/proxy-ca.crt
```

### 6. Certificate Rotation
ECH certificates are rotated automatically by the platform. After rotation:
- Clients trusting the CA (not the specific cert) continue to work without any changes
- Clients using **certificate pinning** will fail — the specific cert hash changes on rotation

**If you've pinned a specific ECH certificate: remove the pin and trust the CA chain instead.** Certificate pinning is not recommended for ECH endpoints due to automatic rotation.

### 7. Hostname / SAN Mismatch
ECH endpoint certificates have SANs matching their hostname pattern:
```bash
openssl s_client -connect <es-endpoint>:443 -servername <es-endpoint> 2>/dev/null \
  | openssl x509 -noout -text | grep "DNS:"
```

SAN mismatch causes (`SSL: CERTIFICATE_VERIFY_FAILED` with hostname mismatch):
- Client connecting to an **IP address** instead of the hostname — always use the full hostname
- Using a **CNAME alias** that points to ECH but the cert only covers the original ECH hostname
- Accessing via an **intermediate proxy hostname** that differs from the ECH endpoint

Always connect to ECH using the full hostname from the console, never by IP address.

### 8. Expired Certificate
```bash
# Check certificate expiry
openssl s_client -connect <es-endpoint>:443 -servername <es-endpoint> 2>/dev/null \
  | openssl x509 -noout -dates

# Check days remaining
openssl s_client -connect <es-endpoint>:443 -servername <es-endpoint> 2>/dev/null \
  | openssl x509 -noout -checkend 604800  # Check if expires within 7 days
```

For ECH, certificate renewal is automatic — if a cert appears expired, it is a platform issue. Contact Elastic Support.

### 9. Client Trust Configuration for Elastic Clients
Beats, Elastic Agent, and Logstash connecting to ECH:
```yaml
# filebeat.yml / elastic-agent outputs
output.elasticsearch:
  hosts: ["https://<es-endpoint>:443"]
  # Do NOT set ssl.certificate_authorities for ECH — public CA is trusted by OS
  # Exception: if corporate SSL inspection is in use, set:
  ssl:
    certificate_authorities: ["/path/to/corporate-proxy-ca.crt"]
```

For Java-based clients (Logstash, Java SDK):
```yaml
# logstash.conf
output {
  elasticsearch {
    hosts => ["https://<es-endpoint>:443"]
    # No ssl_certificate_authority needed for ECH — uses JVM cacerts
    # If SSL inspection: add proxy CA to JVM cacerts (see step 5)
  }
}
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific TLS error message, the client type (Java/Python/Beats/Agent/browser), the cloud provider and region, and whether SSL inspection is in use.

## Token Budget
- `openssl s_client` + cert inspection gives instant diagnosis of cert trust issues.
- Check issuer chain first to identify SSL inspection before any other step.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
