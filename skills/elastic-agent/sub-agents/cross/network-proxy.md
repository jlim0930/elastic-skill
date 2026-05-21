---
name: cross-network-proxy
description: Diagnoses cross-component network and proxy issues including port reference for all Elastic components, proxy configuration affecting multiple components, firewall rules for Elastic ecosystem, DNS resolution across components, and load balancer behavior.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Cross-Component — Network & Proxy Sub-Agent

Scope: Port reference for all Elastic components, proxy configuration affecting multiple components, firewall requirements for Elastic ecosystem, DNS issues, load balancer behavior (idle timeout, health checks).

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"Elastic Stack network ports firewall"`, `"Elastic Agent proxy configuration"`, `"Fleet Server load balancer"`, `"Elastic Stack DNS resolution"`, `"Beats proxy network"`.

## Diagnostic Steps

### 1. Elastic Stack Port Reference
| Component | Port | Protocol | Direction | Notes |
|-----------|------|----------|-----------|-------|
| Elasticsearch | 9200 | HTTPS | Inbound | REST API |
| Elasticsearch | 9300 | TLS | Internal | Transport (node-to-node) |
| Kibana | 5601 | HTTPS | Inbound | UI and API |
| Fleet Server | 8220 | HTTPS | Inbound | Agent check-in |
| Logstash | 5044 | TLS | Inbound | Beats input |
| Logstash | 9600 | HTTP | Inbound | Monitoring API |
| APM Server | 8200 | HTTPS | Inbound | APM agent intake |
| Elastic Agent | (none) | — | Outbound only | Initiates connections |
| Beats | (none) | — | Outbound only | Initiates connections |

### 2. Connectivity Test Matrix
```bash
# From Elastic Agent host, test all required endpoints
for ep in "<es-host>:9200" "<kibana-host>:5601" "<fleet-server>:8220"; do
  nc -z -w5 $(echo $ep | tr ':' ' ') && echo "$ep: OK" || echo "$ep: FAIL"
done

# From Beat host
for ep in "<logstash>:5044" "<es-host>:9200"; do
  nc -z -w5 $(echo $ep | tr ':' ' ') && echo "$ep: OK" || echo "$ep: FAIL"
done
```

### 3. Proxy Configuration
Elastic components respect standard HTTP proxy environment variables:
```bash
env | grep -iE "http_proxy|https_proxy|no_proxy"
```
Set proxy for systemd services:
```ini
# /etc/systemd/system/elastic-agent.service.d/proxy.conf
[Service]
Environment="HTTPS_PROXY=http://proxy.corp:3128"
Environment="NO_PROXY=localhost,127.0.0.1,.internal.corp"
```
```bash
systemctl daemon-reload && systemctl restart elastic-agent
```

### 4. Per-Component Proxy Config
```yaml
# Elastic Agent standalone (elastic-agent.yml)
agent.proxy_url: http://proxy.corp:3128
agent.proxy_disable: false
agent.proxy_headers:
  Proxy-Authorization: Basic <base64>

# Filebeat (filebeat.yml)
output.elasticsearch:
  proxy_url: http://proxy.corp:3128

# APM Server
apm-server:
  proxy_url: http://proxy.corp:3128
```

### 5. Load Balancer Configuration for Fleet Server
```bash
# Test Fleet Server through LB
curl -s https://<lb-host>:8220/api/status | jq '.status'
```
LB requirements for Fleet Server:
- **Protocol**: TCP/TLS passthrough (not HTTP termination for agent check-ins)
- **Idle timeout**: ≥ 75s (agents default check-in is 30s; use 75s for buffer)
- **Health check**: TCP check on port 8220 or HTTPS GET `/api/status`
- **Session persistence**: not required (Fleet Server is stateless)

### 6. DNS Resolution
```bash
# Test DNS from each component host
nslookup <fleet-server-hostname>
nslookup <es-hostname>
dig <fleet-server-hostname> +short

# Test reverse DNS (needed for some TLS configs)
host <ip-address>
```
DNS TTL too low + frequent IP changes = transient connection failures. Set a reasonably long TTL or use IPs.

### 7. Firewall Rules Checklist
```bash
# Check firewall on the host
iptables -L INPUT -n -v | grep -E "9200|9300|8220|5601|5044|8200"
firewall-cmd --list-all 2>/dev/null | grep -E "9200|8220|5044"
```
Required firewall rules:
- Agent hosts → Fleet Server 8220: ALLOW
- Agent hosts → Elasticsearch 9200: ALLOW (if direct ES output)
- Beats hosts → Logstash 5044: ALLOW
- APM agent hosts → APM Server 8200: ALLOW
- Elasticsearch nodes → Elasticsearch nodes 9300: ALLOW (internal)

### 8. Network Interface / MTU
```bash
# Check MTU (Jumbo frames can cause issues)
ip link show | grep -E "mtu|eth|ens|bond"
# If MTU mismatch: reduce Beat/Agent connection MTU
# Or fix MTU at network level
```

### 9. IPv6 / Dual-Stack
```bash
# Check if any component binds to IPv6
ss -tlnp | grep -E ":::9200|:::8220|:::5601|:::8200"
# Force IPv4 if needed
echo "network.host: _local:ipv4_" >> /etc/elasticsearch/elasticsearch.yml
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific component pair, port, and network error.

## Token Budget
- `nc -z` connectivity matrix before any log analysis.
- Port reference table is embedded — look here first before web search.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
