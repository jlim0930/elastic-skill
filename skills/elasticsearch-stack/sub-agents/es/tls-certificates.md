---
name: es-tls-certificates
description: Diagnoses Elasticsearch TLS/SSL errors including SSLHandshakeException, PKIX path building failures, peer not authenticated, certificate expiry, CA chain issues, PEM vs PKCS#12 format mismatches, and transport vs HTTP SSL misconfiguration.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — TLS / Certificates

**Purpose**: Identify whether TLS errors are caused by cert expiry, CA chain gaps, format mismatch, or wrong config block, and prescribe the fix.

## Use When
- `SSLHandshakeException` or `PKIX path building failed` in logs
- `peer not authenticated` or `certificate_verify_failed`
- Nodes cannot communicate after cert rotation
- Kibana or clients cannot connect to ES over HTTPS

## Do Not Use When
- Network port unreachable (not TLS) → es/network-transport
- Auth fails after TLS succeeds (401/403) → es/security-access

## Inputs Needed
- Exact error message (SSLHandshake vs PKIX vs peer not authenticated)
- Whether error is on HTTP (9200) or transport (9300)
- Certificate format in use (PEM or PKCS#12)
- ES version (hot reload available 8.4+)

## Diagnostic Logic

### Error Classification
| Error | Cause | First Check |
|---|---|---|
| `SSLHandshakeException` | Protocol/cipher mismatch or expired cert | Cert validity dates; TLS version config |
| `PKIX path building failed` | CA not trusted by receiving node | CA cert in truststore on both sides |
| `peer not authenticated` | mTLS: client cert required but not provided | `verification_mode` setting; client cert present? |
| `certificate_verify_failed` | Hostname not in SAN | SAN/CN matches DNS name or IP used |
| `no cipher suites in common` | TLS version restriction | `supported_protocols` settings |

### HTTP vs Transport — Separate Config Blocks
- `xpack.security.http.ssl.*` → HTTPS on 9200 (clients, Kibana)
- `xpack.security.transport.ssl.*` → inter-node on 9300
- Error on 9200 only → check HTTP block; error on 9300 only → check transport block
- Each block has independent `keystore.path`, `truststore.path`, `certificate_authorities`

### Certificate Format Rules
- PEM: uses `certificate`, `key`, `certificate_authorities` fields
- PKCS#12: uses `keystore.path` + `keystore.password`; truststore not needed if CA is bundled
- Mixing formats (PEM cert with keystore path) → silent misconfiguration
- Verify format fields match the keys used in elasticsearch.yml

### CA Chain Validation
- All nodes must trust the CA that signed other nodes' certs
- Self-signed CA: CA cert must be in `certificate_authorities` on every node
- Intermediate CA: full chain (leaf → intermediate → root) must be present
- CCS/CCR: remote cluster CA must be trusted on local cluster

### Cert Rotation (8.4+)
- Update cert files on disk, then trigger reload via `_nodes/reload_secure_settings`
- No restart needed for hot reload (8.4+); full restart required on earlier versions
- Old cert must not expire before rotation completes — overlap window required
- After rotation: verify both HTTP and transport blocks independently

### Common Misconfigurations
| Symptom | Check |
|---|---|
| Inter-node fails, clients OK | Transport block missing CA or wrong cert |
| Only Kibana fails | HTTP block cert expired or hostname not in SAN |
| All fail after rotation | Reload not triggered; old keystore still loaded |
| Cert valid but hostname error | SAN must include all DNS names AND IPs the node uses |

## Shared Skills
→ [tls_certificate_checks](../../../../shared/tls_certificate_checks.md) — full 6-step TLS decision tree
→ [log_filtering](../../../../shared/log_filtering.md) — filter for SSL/TLS exception names

## KCS Queries
`"SSLHandshakeException elasticsearch PKIX path"`, `"peer not authenticated elasticsearch transport"`, `"certificate rotation reload elasticsearch"`, `"PEM PKCS12 elasticsearch TLS config"`

## Output
Report: error type, which SSL block (HTTP/transport), cert validity status, CA chain gap or format mismatch, fix steps.
