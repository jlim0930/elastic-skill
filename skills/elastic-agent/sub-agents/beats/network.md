---
name: beats-network
description: Diagnoses Beats network connectivity failures including DNS resolution errors, proxy configuration, firewall blocking, load balancer issues, output host unreachable, and Beats-to-Logstash or Beats-to-Elasticsearch connectivity problems.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Beats — Network Sub-Agent

Scope: DNS resolution errors, proxy configuration, firewall blocking, load balancer idle timeout, output host unreachable, Beats→Logstash and Beats→Elasticsearch connectivity.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"filebeat connection refused elasticsearch"`, `"beats proxy configuration"`, `"filebeat DNS resolution failed"`, `"beats load balancer connection reset"`, `"filebeat network timeout"`.

## Diagnostic Steps

### 1. Network Error Summary
```bash
grep -E "connection.*refused|dial.*error|no.*route|network.*unreachable|timeout|EOF|reset.*connection" \
  /var/log/filebeat/filebeat | tail -20
```
Key patterns:
- `connection refused` = service not listening on the port, or firewall DROP/REJECT
- `no route to host` = routing issue or firewall REJECT
- `i/o timeout` = firewall silently dropping packets, or host not responding
- `EOF` = connection reset mid-stream (LB idle timeout, keepalive misconfiguration)

### 2. Output Host Configuration
```bash
grep -E "hosts:|host:" /etc/filebeat/filebeat.yml | head -10
```
Verify the configured host is correct:
```bash
# Test connectivity
nc -z -w5 <es-host> 9200 && echo "reachable" || echo "unreachable"
nc -z -w5 <logstash-host> 5044 && echo "reachable" || echo "unreachable"

# DNS resolution
nslookup <es-host>
dig <es-host> +short
```

### 3. Firewall Check
```bash
# From the Beat host to ES
curl -sv http://<es-host>:9200/ 2>&1 | grep -E "Connected|refused|timeout|< HTTP"

# Trace route to identify where connection is dropped
traceroute <es-host> 2>/dev/null | tail -5
```

### 4. Proxy Configuration
```bash
grep -E "proxy|http_proxy|https_proxy|no_proxy" /etc/filebeat/filebeat.yml 2>/dev/null
env | grep -i proxy
```
Beats respect environment variables `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`.
If a proxy is required but not configured, Beats will attempt direct connection.
```yaml
# Explicit proxy in Beat config
output.elasticsearch:
  proxy_url: http://proxy.corp:3128
  proxy_disable: false
```

### 5. Load Balancer Idle Timeout
Symptom: Beat works initially, then gets `EOF` errors after period of inactivity.
```bash
grep -E "EOF|connection.*reset|keepalive" /var/log/filebeat/filebeat | tail -10
```
Cause: LB closes idle TCP connections before Beat's keepalive kicks in.
Fix: reduce Beat's keepalive interval or increase LB idle timeout.
```yaml
output.elasticsearch:
  idle_connection_timeout: 60s  # close idle connections before LB does
```

### 6. Output Load Balancing
If multiple ES hosts are configured:
```yaml
output.elasticsearch:
  hosts: ["es1:9200", "es2:9200", "es3:9200"]
  loadbalance: true
```
Beat uses round-robin. If one host fails, Beat retries others. Check which host is failing:
```bash
grep -E "failed.*es[0-9]|es[0-9].*failed|host.*unavailable" /var/log/filebeat/filebeat | tail -10
```

### 7. Logstash Output — Beats Input Port
Default Logstash Beats input port is 5044/TCP.
```bash
# On Logstash host
ss -tlnp | grep 5044
# On Beat host
nc -z -w5 <logstash-host> 5044 && echo "OK" || echo "FAIL"
```
If Logstash is listening but Beat can't connect: check firewall rules between hosts.

### 8. Air-Gapped / No Internet Connectivity
Beats do not require internet connectivity during normal operation.
If Beat fails with `no such host` on startup: DNS not configured or /etc/hosts entry missing.
```bash
cat /etc/resolv.conf
ping -c2 <es-host> 2>/dev/null
```

### 9. IPv6 / Dual-Stack Issues
```bash
# Force IPv4
grep "hosts:" /etc/filebeat/filebeat.yml
# Use explicit IPv4 address instead of hostname if IPv6 is causing issues
```
If the hostname resolves to IPv6 but the service listens on IPv4 only: use the IPv4 address directly or configure DNS to return A records.

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific network error and output type.

## Token Budget
- `nc -z` connectivity test before any log analysis.
- `grep` for connection error patterns before reading full config.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
