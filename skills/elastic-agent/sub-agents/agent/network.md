---
name: agent-network
description: Diagnoses Elastic Agent cannot reach Fleet Server, cannot reach Elasticsearch output, proxy misconfiguration, firewall/port blocking, DNS resolution failures, timeout errors, air-gapped environment connectivity, and load balancer/reverse proxy issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Elastic Agent — Network Connectivity Sub-Agent

Scope: agent cannot reach Fleet Server, cannot reach Elasticsearch output, proxy misconfiguration, firewall/port blocking, DNS resolution failures, timeout errors, air-gapped environment connectivity/package retrieval, load balancer/reverse proxy issues.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"elastic-agent cannot reach Fleet Server"`, `"elastic-agent proxy configuration"`, `"elastic-agent firewall port"`, `"elastic-agent air-gapped environment"`, `"elastic-agent DNS resolution failed"`.

## Diagnostic Steps

### 1. Network Errors in Logs
```bash
grep -E "connection.*refused|timeout|no such host|dial.*tcp|proxy|network" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -30
```

### 2. Fleet Server Reachability
```bash
# Port check
nc -zv <fleet-server-host> 8220
# HTTP check
curl -v https://<fleet-server-host>:8220/api/status
# DNS resolution
nslookup <fleet-server-host>
dig <fleet-server-host> +short
```

### 3. Elasticsearch Output Reachability
```bash
nc -zv <es-host> 9200
curl -v https://<es-host>:9200/_cluster/health
```

### 4. Proxy Configuration
```bash
elastic-agent inspect --output yaml | grep -E "proxy|proxy_url|proxy_headers"
```
Agent proxy settings:
- Set via environment variables: `HTTPS_PROXY`, `HTTP_PROXY`, `NO_PROXY`.
- Or in `elastic-agent.yml`: `fleet.proxy_url: "http://<proxy>:3128"`.
```bash
env | grep -iE "https_proxy|http_proxy|no_proxy"
```
Proxy misconfiguration = all requests routed through wrong proxy or bypassing needed proxy.

### 5. Firewall / Port Blocking
Required ports:
- Agent → Fleet Server: `8220/TCP`
- Agent → Elasticsearch: `9200/TCP`
- Agent → APM Server: `8200/TCP` (if APM input)
```bash
# Test from agent host
nc -zv <fleet-server-host> 8220 && echo "OK" || echo "BLOCKED"
nc -zv <es-host> 9200 && echo "OK" || echo "BLOCKED"
```

### 6. DNS Resolution
```bash
nslookup <fleet-server-hostname>
# If resolution fails, check /etc/resolv.conf
cat /etc/resolv.conf
# Test with explicit DNS server
nslookup <fleet-server-hostname> 8.8.8.8
```

### 7. Load Balancer / Reverse Proxy
If Fleet Server is behind an LB:
- LB must support long-lived connections (HTTP/2 keep-alive, not just short-lived HTTP/1.1).
- LB idle timeout must be ≥ agent check-in interval (default 30s). Set LB timeout to at least 90s.
- LB must forward the original `Host` header.
```bash
grep -E "LB|load.balancer|reverse.proxy|nginx|haproxy" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -10
```

### 8. Air-Gapped Environment
In air-gapped setups, agents cannot reach `artifacts.elastic.co` for package downloads.
```bash
grep -E "artifacts|download.*package|air.gap" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -10
```
Solutions:
- Use a local package registry (EPR): set `ELASTIC_AGENT_ARTIFACT_STORE_BASE_URL` or configure in Fleet settings.
- Pre-download integration packages and serve internally.

### 9. Timeout Errors
`Client.Timeout exceeded` = network too slow or Fleet Server overloaded.
```bash
grep -E "timeout|deadline|context canceled" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -20
```
Increase timeout in agent config or investigate Fleet Server performance.

### 10. KCS + Docs Lookup
Execute retrieval protocol now with the connectivity error type and component pair.

## Token Budget
- `nc -zv` + `curl -v` for immediate connectivity test — no log analysis needed first.
- `grep` for network-specific keywords in logs once basic connectivity is confirmed.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
