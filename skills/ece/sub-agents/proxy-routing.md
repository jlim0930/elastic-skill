---
name: ece-proxy-routing
description: Diagnoses ECE proxy, route server, and forwarder failures causing 502/503/504 errors or client connectivity issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE Proxy and Routing Sub-Agent

Scope: HTTP 502/503/504 errors, proxy container failures, route server unavailability, service/route forwarder issues, stunnel TLS proxy.

## Retrieval Protocol
Follow [../../../shared/retrieval-protocol.md](../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE proxy 502 503"`, `"ECE route server failed"`, `"ECE stunnel proxy connection"`.

## Diagnostic Steps

### 1. Proxy Container Status
```bash
docker ps -a --filter "name=frc-proxies"
# or Podman:
podman ps -a --filter "name=frc-proxies"
```
Proxy containers must be `Up`. If `Exited` or restarting, check logs:
```bash
docker logs frc-proxies --tail 200
```

### 2. Route Server Status
```bash
docker ps -a --filter "name=frc-route-servers"
docker logs frc-route-servers --tail 200
```
Route server manages routing tables. If it is down, proxies cannot resolve cluster endpoints.

### 3. Port Binding
```bash
ss -lntp | grep -E "9200|9243|12400|12443"
```
ECE proxy listens on 9200 (HTTP) and 9243 (HTTPS). Missing ports = proxy not bound.

### 4. Connectivity Test
From a client host:
```bash
curl -v https://<proxy-host>:9243/_cluster/health -u <user>:<pass> -k
openssl s_client -connect <proxy-host>:9243 -showcerts
```
- TLS handshake failure → stunnel/certificate issue; escalate to certificate specialist.
- Connection refused → proxy not listening; check port binding (Step 3).
- 502 → proxy up but cannot reach ES; check route server.

### 5. Service Forwarder / Route Forwarder
```bash
docker logs frc-service-forwarders --tail 100
docker logs frc-route-forwarders --tail 100
```
Forwarder errors indicate internal routing table corruption or allocator connectivity issues.

### 6. Allocator-to-Proxy Network
Verify network reachability between allocators and proxy hosts:
```bash
nc -zv <allocator-host> 9300  # transport port
nc -zv <proxy-host> 12400     # internal routing port
```

### 7. KCS + Docs Lookup
Execute retrieval protocol now. Query with the HTTP error code and the failing container name.

## Token Budget
- Extract only the last 50 error lines from each container log.
- `grep -E "ERROR|WARN|refused|timeout|5[0-9][0-9]"` before reading context.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../shared/output-format.md](../../../shared/output-format.md).
Reference thresholds from [../../../shared/thresholds.md](../../../shared/thresholds.md).
