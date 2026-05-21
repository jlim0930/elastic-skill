---
name: cross-certificate-tls
description: Diagnoses cross-product TLS issues spanning Elasticsearch, Kibana, Logstash, Beats, and Elastic Agent — including CA trust chain gaps, SAN mismatches, certificate expiry, PEM/PKCS12/JKS format compatibility, mutual TLS configuration, and rolling certificate rotation procedures.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Cross-Product — Certificate / TLS

**Purpose**: Classify TLS errors by component and layer, verify CA trust and SAN coverage, and prescribe the cert fix or rotation path.

## Use When
- TLS handshake failure between any pair of stack components
- Browser or component shows certificate error, expiry, or SAN mismatch
- Cert rotation required without downtime
- mTLS needed between Beats→Logstash or Kibana→ES

## Do Not Use When
- TLS error is only within one component → use that component's tls sub-agent
- Network port unreachable (not TLS) → cross-product/network

## Inputs Needed
- Error pattern from log (exact exception name)
- Component pair involved (e.g., Kibana→ES, Beats→Logstash)
- Certificate format in use (PEM, PKCS#12, JKS)
- Whether CA is self-signed/internal or public

## Diagnostic Logic

### TLS Error Classification
| Error Pattern | Component | Cause |
|---|---|---|
| `SSLHandshakeException` | ES or Logstash (Java) | CA mismatch, untrusted cert, or expired |
| `unable to verify the first certificate` | Kibana (Node.js) | Incomplete CA chain |
| `hostname verification failed` | Any | SAN missing the hostname/IP in use |
| `CERT_HAS_EXPIRED` | Any | Certificate past `notAfter` date |
| `connection reset by peer` after TLS | Any | TLS version or cipher mismatch |
| `SSLError: WRONG_VERSION_NUMBER` | Beats (Go) | Connecting to non-TLS port |

### Certificate Expiry Check
- Check `notAfter` date on certs at all component paths
- Expiry within 30 days = immediate rotation needed
- Live endpoint check: confirm cert served matches file on disk

### SAN Verification
SAN must include every hostname, FQDN, and IP that connecting components use.

| Scenario | Missing SAN Entry |
|---|---|
| Multi-node ES cluster | Other node IPs |
| Kibana→ES via load balancer | LB hostname/IP |
| Beats→Logstash | Logstash FQDN clients use |
| `verify: false` set as workaround | Fix SAN instead |

### CA Trust Chain Rules
- Each component must trust the CA of **every component it connects to**
- Components do not need to share one CA — but trust must be mutual
- `unable to get issuer certificate` = intermediate CA missing from chain
- Fix: concatenate leaf → intermediate → root into a single chain file

### Format Requirements by Component
| Component | Preferred Format | Notes |
|---|---|---|
| Elasticsearch | PKCS#12 or PEM | Both supported; PKCS#12 simpler |
| Kibana | PEM only | Node.js does not support PKCS#12 natively |
| Logstash | JKS or PKCS#12 | Java-based; JKS for older plugins |
| Logstash beats input (8.x+) | PEM | SSL settings changed in 8.x |
| Beats / Elastic Agent | PEM | Go-based; PEM only |

### Mutual TLS (mTLS)
- mTLS = both sides present AND verify certificates
- Kibana→ES: set `elasticsearch.ssl.certificate` and `.key` in kibana.yml
- Beats→Logstash: set `ssl_client_authentication: required` on Logstash beats input; configure cert/key in filebeat.yml

### Certificate Generation (elasticsearch-certutil)
1. Generate CA → outputs PKCS#12 or PEM CA bundle
2. Generate component certs from that CA specifying `--dns` and `--ip` SANs per component
3. Bulk generation: use `instances.yml` with all component names, DNS, and IPs
4. Convert format as needed per component preference table above

### Rolling Certificate Rotation (Zero Downtime)
1. Generate new certs with extended validity and all required SANs
2. Distribute new cert files without replacing old ones yet
3. Add new CA to existing CA bundles (dual-trust period — old + new CA both trusted)
4. Rolling restart ES: one node at a time; verify cluster health between restarts
5. Restart Kibana (stateless — single restart safe)
6. Restart Logstash after cert update
7. Update Beats/Agent (rolling)
8. Remove old CA from trust stores once all components serve new certs

**ES 8.4+**: TLS hot reload supported — no restart required after updating cert files on disk.

## Shared Skills
→ [tls_certificate_checks](../../../../shared/tls_certificate_checks.md) — expiry, CA chain, SAN, format validation steps
→ [log_filtering](../../../../shared/log_filtering.md) — filter for SSLHandshakeException, hostname mismatch, CERT_HAS_EXPIRED across component logs

## KCS Queries
`"elastic stack TLS certificate elasticsearch-certutil SAN"`, `"SSLHandshakeException CA trust chain kibana logstash beats"`, `"certificate rotation rolling restart elastic stack zero downtime"`, `"mTLS mutual TLS beats logstash elasticsearch kibana"`

## Output
Report: error classification (component + layer), expiry status, SAN gap, CA trust issue, format mismatch, and recommended rotation or config fix.
