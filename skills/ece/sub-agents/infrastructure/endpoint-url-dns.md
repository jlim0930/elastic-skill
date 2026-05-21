---
name: ece-endpoint-url-dns
description: Diagnoses ECE endpoint URL and DNS issues including changed endpoint URL breaking access, wildcard DNS misconfiguration, custom endpoint alias issues, AWS endpoint and private IP mismatch, proxy certificate no longer matching the endpoint, and public vs internal hostname confusion.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE — Endpoint URL / DNS Sub-Agent

Scope: Changed endpoint URL breaking access, wildcard DNS misconfiguration, custom endpoint alias issues, AWS private/public IP endpoint mismatch, proxy cert SAN mismatch after endpoint change, public vs internal hostname confusion.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE endpoint URL changed"`, `"ECE wildcard DNS misconfiguration"`, `"ECE custom endpoint alias"`, `"ECE AWS endpoint mismatch"`, `"ECE proxy certificate endpoint"`.

## Diagnostic Steps

### 1. ECE Endpoint Architecture
ECE deployment endpoints follow the pattern:
```
<cluster-name>.<ece-wildcard-domain>:<port>
```
Example: `my-cluster.ece.example.com:9243`

The wildcard domain (`ece.example.com`) is configured at ECE install time or set via:
Platform → Settings → Endpoint URL

### 2. Check Current Endpoint Configuration
```bash
# Platform-level endpoint domain
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform" | jq '.domain_name'

# Deployment endpoint
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>" | \
  jq '{endpoint: .metadata.endpoint, cluster_name: .cluster_name}'
```

### 3. Changed Endpoint URL Breaking Access
If the ECE platform domain name was changed:
1. Old endpoints (using old domain) no longer route correctly
2. DNS no longer resolves old endpoints
3. Proxy certificate SANs may not cover new domain

Check current vs. historical domain:
```bash
# Current platform domain
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform" | jq '.domain_name'

# Compare with what clients are using
nslookup <old-endpoint>
nslookup <new-endpoint>
```

### 4. Wildcard DNS Requirements
ECE requires a wildcard DNS record:
```
*.ece.example.com → <proxy-ip>
```
If wildcard DNS is missing or misconfigured:
```bash
# Test wildcard DNS resolution
nslookup test.ece.example.com  # should resolve to proxy IP
nslookup another.ece.example.com  # should also resolve to proxy IP

# Verify proxy IP
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform/infrastructure/proxies" | \
  jq '.proxies[] | {id:.proxy_id, ip:.proxy_address}'
```
If DNS doesn't resolve: clients cannot reach any deployment endpoint.

### 5. Custom Endpoint Aliases
ECE supports custom domain aliases for deployment endpoints:
```bash
# Check custom aliases for a deployment
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>" | \
  jq '.metadata.aliases'

# Add an alias
curl -s -k -u admin:<pass> -XPOST \
  "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>/aliases" \
  -H "Content-Type: application/json" \
  -d '{"aliases": ["custom-alias.example.com"]}' | jq '.'
```
If a custom alias is used but not in the proxy certificate SANs: TLS errors occur.

### 6. AWS Private vs. Public IP Endpoint Mismatch
On AWS, ECE proxies have both private (10.x.x.x) and public IPs.
If ECE is configured with the private IP but the wildcard DNS points to the public IP (or vice versa):
```bash
# Check ECE proxy configured address
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform/infrastructure/proxies" | \
  jq '.proxies[] | {id:.proxy_id, addr:.proxy_address}'

# Check what DNS resolves to
dig <deployment-endpoint> +short

# If mismatch: update proxy address in ECE
curl -s -k -u admin:<pass> -XPUT "https://localhost:12443/api/v1/platform/infrastructure/proxies/<proxy-id>" \
  -H "Content-Type: application/json" \
  -d '{"proxy_address": "<correct-ip>"}' | jq '.'
```

### 7. Proxy Certificate SAN After Endpoint Change
After changing the endpoint domain, the proxy certificate must be updated:
```bash
# Check if new domain is in certificate SANs
openssl s_client -connect <proxy-ip>:9243 -servername <new-endpoint> 2>/dev/null \
  | openssl x509 -noout -text | grep -E "DNS:|IP:"
```
If the new domain is not in the SANs: upload a new certificate that includes it.
See `tls-certificates.md` for certificate rotation procedure.

### 8. Public vs. Internal Hostname
ECE deployments may have different hostnames for internal vs. external access:
- Internal: `my-cluster.internal.ece.example.com` (resolves to private IP)
- External: `my-cluster.ece.example.com` (resolves to public IP or LB)

Clients inside the network should use the internal hostname; external clients use the external.
If a client uses the wrong hostname variant: DNS may not resolve or may route incorrectly.

### 9. DNS Resolution Debug
```bash
# Test from different network perspectives
nslookup <deployment-endpoint> <internal-dns-server>
nslookup <deployment-endpoint> <public-dns-server>
nslookup <deployment-endpoint> 8.8.8.8

# Check TTL (too short can cause issues)
dig <deployment-endpoint> | grep "TTL"
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the endpoint pattern, DNS error, and ECE version.

## Token Budget
- `nslookup` + `curl -sv` endpoint test gives instant DNS/connectivity diagnosis.
- Check platform domain name before investigating DNS configuration.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
