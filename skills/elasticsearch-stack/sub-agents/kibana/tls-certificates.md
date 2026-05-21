---
name: kb-tls-certificates
description: Diagnoses Kibana HTTPS enablement configuration errors, browser certificate trust warnings, Kibana-to-Elasticsearch TLS handshake failures, reverse proxy TLS termination misconfiguration, client certificate authentication, and expired or incomplete CA chain issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# KB — TLS / Certificates

**Purpose**: Identify whether TLS errors are browser-to-Kibana, Kibana-to-ES, or proxy-related, and prescribe the fix.

## Use When
- Browser shows "Not Secure" or certificate error on Kibana
- `SSLHandshakeException` in Kibana log (connecting to ES)
- Kibana HTTPS not working after enabling TLS
- Reverse proxy cert mismatch with Kibana

## Do Not Use When
- Login fails after TLS succeeds → kibana/login-authentication
- Network port unreachable (not TLS) → shared/network_connectivity_checks

## Inputs Needed
- Error pattern (browser error vs Kibana log error)
- Whether error is browser→Kibana or Kibana→ES
- Certificate format (PEM, PKCS#12)
- Reverse proxy in use (nginx, HAProxy, etc.)

## Diagnostic Logic

### Error Classification by Layer
| Error | Layer | Cause |
|---|---|---|
| `SSLHandshakeException` | Kibana → ES | CA mismatch or cert not trusted |
| `unable to verify the first certificate` | Kibana → ES | Incomplete CA chain |
| `CERT_HAS_EXPIRED` | Either | Certificate past `notAfter` date |
| `ERR_CERT_AUTHORITY_INVALID` | Browser → Kibana | Self-signed or internal CA not in browser trust |
| `ECONNREFUSED` on port 5601 | Browser → Kibana | Kibana not listening on HTTPS |
| `Error: write EPROTO` | Kibana → ES | TLS version mismatch |

### Kibana HTTPS Config
- Required: `server.ssl.enabled: true`, `server.ssl.certificate`, `server.ssl.key`
- Cert and key must match (same modulus) — mismatch = startup failure
- Restrict protocols: `server.ssl.supportedProtocols: ["TLSv1.2", "TLSv1.3"]`

### Kibana-to-Elasticsearch TLS
- Set `elasticsearch.ssl.certificateAuthorities` to the CA that signed the ES server cert
- Verification modes: `full` (cert + hostname), `certificate` (cert only), `none` (insecure)
- `none` is for debugging only — never use in production
- ES hostname Kibana connects to must be in ES cert SAN

### Browser Trust Warning
- Self-signed CA → not in browser OS trust store → browser shows warning
- Fix: distribute and install CA cert in OS trust store on client machines
- For public CA: ensure full cert chain (leaf → intermediate → root) is in `kibana.crt`

### Reverse Proxy TLS Patterns
| Pattern | Kibana Config | Proxy Config |
|---|---|---|
| TLS terminated at proxy, Kibana HTTP | `server.ssl.enabled: false` | Proxy sets `X-Forwarded-Proto: https` |
| TLS at both proxy and Kibana | `server.ssl.enabled: true` | Proxy trusts Kibana's CA |
| mTLS between proxy and Kibana | `server.ssl.clientAuthentication: optional` | Proxy presents client cert |

- `server.publicBaseUrl` must be the public HTTPS URL when TLS is terminated at the proxy
- Missing `publicBaseUrl` → alert links and report URLs use wrong scheme/hostname

### Certificate Validity and Chain
- Check cert expiry and SAN coverage before diagnosing config issues
- Intermediate CA gap → `unable to get issuer certificate`
- Fix: build full chain file concatenating leaf → intermediate → root CA
- Cert/key modulus must match (mismatch = startup failure with cryptic error)

## Shared Skills
→ [tls_certificate_checks](../../../../shared/tls_certificate_checks.md) — full 6-step TLS decision tree (expiry, CA, SAN, format)
→ [log_filtering](../../../../shared/log_filtering.md) — filter for SSL/TLS exception names in Kibana log

## KCS Queries
`"kibana HTTPS TLS certificate error startup"`, `"kibana elasticsearch TLS SSLHandshakeException"`, `"kibana browser trust warning self-signed CA"`, `"kibana reverse proxy TLS termination publicBaseUrl"`

## Output
Report: error layer (browser/Kibana-to-ES/proxy), cert validity, CA chain gap, config mismatch, fix.
