# TLS / Certificate Checks

**Purpose**: Structured decision tree for diagnosing TLS and certificate issues across any Elastic Stack component.

## Step 1 — Identify the Error Type
| Error Signal | Category |
|---|---|
| `SSLHandshakeException`, `certificate verify failed` | CA/chain trust failure |
| `hostname verification failed`, `CERT_HAS_EXPIRED` | Cert validity / SAN mismatch |
| `connection refused` on TLS port | Service not listening or TLS not enabled |
| Browser `ERR_CERT_AUTHORITY_INVALID` | Browser doesn't trust CA |
| `No usable sandbox` (Chromium) | Unrelated — see Kibana Reporting |

## Step 2 — Check Certificate Validity
- Is the certificate expired? (check `notAfter`)
- Does the certificate's SAN include the hostname/IP used to connect?
- Does the certificate's issuer match the CA in the trust store?

## Step 3 — Check CA Chain
- Is the full chain present (leaf → intermediate → root)?
- Does each component trust the CA of the component it connects to?
- Are both sides using the same CA, or has the CA been rotated on one side only?

## Step 4 — Check Format Compatibility
| Component | Expected Format |
|---|---|
| Elasticsearch | PKCS#12 or PEM |
| Kibana | PEM (Node.js) |
| Logstash | JKS or PKCS#12 (Java) |
| Beats / Agent | PEM (Go) |

Format mismatch = startup failure or handshake error.

## Step 5 — Check Config Consistency
- Is TLS enabled on both sides of the connection?
- Does `verificationMode` match the cert type (`full` = verify chain + hostname)?
- Is `certificateAuthorities` pointing to the correct CA file?
- Are cert/key paths readable by the service user?

## Step 6 — Check Mutual TLS (if applicable)
- Does the server require client certs? (`ssl_client_authentication: required`)
- Does the client present a cert?
- Is the client's cert trusted by the server's CA?

## Common Causes by Error
| Error | Likely Cause |
|---|---|
| `SSLHandshakeException` | Wrong CA, expired cert, or TLS not enabled on server |
| `unable to verify first certificate` | Incomplete chain (missing intermediate CA) |
| `hostname mismatch` | SAN doesn't include connecting hostname or IP |
| Login loop on Kibana | `server.secureCookies: true` on HTTP-only Kibana |
| Beats TLS post-upgrade | Deprecated `ssl: true` → `ssl_enabled: true` in 8.x |

## Rotation Checklist
1. Generate new cert with all required SANs
2. Distribute to all components
3. Add new CA to trust stores (dual-trust period)
4. Rolling restart: ES → Kibana → Logstash → Beats
5. Remove old CA after all components use new certs
6. ES 8.4+: hot reload available without restart
