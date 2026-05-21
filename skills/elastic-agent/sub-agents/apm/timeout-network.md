---
name: apm-timeout-network
description: Diagnoses APM Server network timeout issues including agent request timeouts, slow event delivery, APM Server behind load balancers with idle timeouts, network latency impact on APM performance, and tail-based sampling network issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# APM Server — Timeout & Network Sub-Agent

Scope: Agent request timeouts, slow event delivery, LB idle timeout causing connection resets, high APM Server latency, proxy configurations, tail-based sampling streaming issues.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"APM agent request timeout"`, `"APM Server load balancer timeout"`, `"APM Server slow response"`, `"APM agent connection reset"`, `"APM tail-based sampling network"`.

## Diagnostic Steps

### 1. APM Server Response Latency
```bash
time curl -s http://localhost:8200/ -o /dev/null
time curl -s -X POST http://localhost:8200/intake/v2/events \
  -H "Content-Type: application/x-ndjson" -d '{}' -o /dev/null
```
> 500ms = APM Server under load or ES backend slow.

### 2. Network Error Patterns
```bash
grep -E "timeout|deadline.*exceeded|connection.*reset|EOF|context.*canceled" \
  /var/log/apm-server/apm-server | tail -20
```
- `context deadline exceeded` = request timed out waiting for ES write
- `EOF` / `connection reset` = LB or client closed connection mid-stream
- `i/o timeout` = network-level timeout to ES

### 3. Load Balancer Idle Timeout
APM agents use long-lived HTTP connections to stream events (especially with streaming agents).
LB idle timeout cutting connections during a low-traffic period:
```bash
grep -E "EOF|reset|idle.*timeout|keepalive" /var/log/apm-server/apm-server | tail -10
```
Fix: increase LB idle timeout or configure APM Server's keepalive:
```yaml
apm-server:
  read_timeout: 3600s   # for streaming agents
  write_timeout: 30s
```

### 4. APM Server → Elasticsearch Latency
APM data path: Agent → APM Server → Elasticsearch. ES slowness directly impacts APM Server throughput.
```bash
time curl -s -o /dev/null http://localhost:9200/_cluster/health
curl -s "http://localhost:9200/_cat/thread_pool/write?v&h=name,active,queue,rejected"
```
Write queue building = APM Server events backing up.

### 5. Proxy Configuration
```bash
grep -E "proxy|proxy_url" /etc/apm-server/apm-server.yml 2>/dev/null
env | grep -i "http_proxy\|https_proxy"
```
If APM Server is behind a forward proxy, the proxy must allow long-lived connections (streaming).
Some proxies buffer responses, which breaks APM Server's streaming intake endpoint.

### 6. TCP Connection State
```bash
# Check connections to/from APM Server port 8200
ss -tn state established sport = :8200 | wc -l
ss -tn state time-wait sport = :8200 | wc -l
```
Many TIME_WAIT = connections closing frequently (not ideal for streaming agents).
Many established = active agent connections.

### 7. Tail-Based Sampling Network Requirements
Tail-based sampling requires agents to hold trace context until a sampling decision is made.
This requires a persistent connection to the APM Server sampling endpoint:
```bash
grep -E "tail.*sampling|sampling.*tail|subscribe" /var/log/apm-server/apm-server | tail -10
```
Network requirements: APM agents must be able to maintain long-lived HTTP/2 connections to APM Server.

### 8. DNS Resolution
```bash
# From agent host
nslookup <apm-server-hostname>
dig <apm-server-hostname> +short

# DNS TTL too short can cause connection issues if IP changes
dig <apm-server-hostname> | grep "TTL"
```

### 9. Concurrent Connection Limits
```bash
grep -E "max.*connection|concurrent|limit" /etc/apm-server/apm-server.yml 2>/dev/null
# Default max connections is high, but OS fd limits can constrain it
cat /proc/$(pgrep -f apm-server | head -1)/limits | grep "open files"
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the timeout error type and APM architecture (standalone vs Fleet).

## Token Budget
- `time curl` for instant latency measurement before log analysis.
- `ss` for connection state overview.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
