---
name: ls-tls-certificates
description: Diagnoses Logstash wrong or missing CA certificate, deprecated SSL settings after upgrades, hostname verification failures, client certificate authentication issues, PEM/JKS/PKCS#12 format confusion, expired certificates, and TLS configuration for both Beats input and Elasticsearch output plugins.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# LS — TLS / Certificates

**Purpose**: Identify whether TLS errors are on the Beats input, ES output, or both, and prescribe the cert or config fix.

## Use When
- `SSLHandshakeException` or `PKIX path building failed` in Logstash logs
- Beats agents cannot connect to Logstash (TLS error)
- Logstash cannot connect to Elasticsearch (SSL error on output)
- Post-upgrade SSL settings deprecated/removed

## Do Not Use When
- Auth fails after TLS succeeds (401/403) → logstash/elasticsearch-output
- Network port unreachable (not TLS) → shared/network_connectivity_checks

## Inputs Needed
- Error message and which plugin (Beats input vs ES output)
- Certificate format in use (PEM, JKS, PKCS#12)
- Logstash version (SSL setting names changed in 8.x)
- Whether client cert authentication is required

## Diagnostic Logic

### Error Classification
| Error | Plugin | Cause |
|---|---|---|
| `SSLHandshakeException` | Input or output | General TLS failure — cert, CA, or SAN |
| `PKIX path building failed` | ES output | Logstash doesn't trust ES server cert |
| `peer not authenticated` | Beats input | Client cert required but not provided |
| `certificate_expired` | Any | Certificate past `notAfter` date |
| Hostname not match | ES output | ES hostname not in cert SAN |

### Beats Input vs ES Output — Separate Configs
- Beats input TLS = Logstash acts as **server** → needs its own cert + key; optionally validates client certs
- ES output TLS = Logstash acts as **client** → needs to trust ES server cert via `cacert`
- Errors on port 5044 → Beats input config
- Errors on port 9200 → ES output config

### Certificate Format Options (Logstash)
| Format | Beats Input Fields | ES Output Fields |
|---|---|---|
| PEM | `ssl_certificate`, `ssl_key`, `ssl_certificate_authorities` | `cacert` |
| JKS | `ssl_keystore_path`, `ssl_keystore_password`, `ssl_truststore_path` | (not supported) |
| PKCS#12 | `ssl_keystore_path`, `ssl_keystore_password` (auto-detected) | (not supported) |

### Client Certificate Authentication (Beats Input)
- `ssl_client_authentication: none` → no client cert required (default)
- `ssl_client_authentication: optional` → accept with or without
- `ssl_client_authentication: required` → Beats must present a valid cert
- When `required`: `ssl_certificate_authorities` must list the CA that signed Beats client certs
- Beats config must set `ssl.certificate` and `ssl.key` pointing to their client cert

### Deprecated SSL Settings (Post-8.x Upgrade)
| Old Setting | Replaced By |
|---|---|
| `ssl => true` (Beats input) | `ssl_enabled => true` |
| `ssl_verify => false` | `ssl_certificate_verification => false` |
| `cacert` in Beats input | `ssl_certificate_authorities => [...]` |
| `verify_mode => "none"` | `ssl_certificate_verification => false` |

- After Logstash upgrade: check startup log for WARN lines containing `deprecated`
- Update all SSL settings to new names to prevent future startup failures

### Hostname Verification
- ES output `ssl_certificate_verification: true` (default) → ES hostname must be in cert SAN
- Connecting by IP address → IP must be in SAN as `IP Address:` entry, not just DNS
- `ssl_certificate_verification: false` → disables hostname check (debugging only)
- Fix: regenerate ES cert with correct SAN including the hostname Logstash uses to connect

## Shared Skills
→ [tls_certificate_checks](../../../../shared/tls_certificate_checks.md) — full 6-step TLS decision tree
→ [log_filtering](../../../../shared/log_filtering.md) — filter for SSL/TLS exception names in Logstash logs

## KCS Queries
`"logstash SSL TLS certificate SSLHandshakeException"`, `"logstash hostname verification failed SAN"`, `"logstash deprecated SSL settings upgrade 8.x"`, `"logstash client certificate authentication beats required"`

## Output
Report: error type, which plugin (input/output), cert validity, CA trust gap or deprecated setting, fix.
