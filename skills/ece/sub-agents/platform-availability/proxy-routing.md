---
name: ece-proxy-routing
description: Diagnoses ECE proxy and routing issues including deployment endpoints unavailable, proxy service down, route server issues, requests not reaching deployments, proxy 502-style failures, routing table inconsistencies, proxy-to-instance connectivity failures, and CCS/CCR routing port issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE — Proxy / Routing Sub-Agent

Scope: Deployment endpoints unavailable, proxy service down, route server issues, requests not reaching deployments, proxy connection/502 failures, routing table inconsistencies, proxy-to-instance connectivity, CCS/CCR routing ports.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE proxy down"`, `"ECE deployment endpoint unavailable"`, `"ECE route server"`, `"ECE proxy 502"`, `"ECE routing table inconsistency"`, `"ECE CCS routing port"`.

## Diagnostic Steps

### 1. Proxy Container Status
```bash
# Check proxy containers
docker ps --filter "name=frc-proxies" --format "{{.Names}}\t{{.Status}}"
docker ps --filter "name=frc-route-servers" --format "{{.Names}}\t{{.Status}}"

# Proxy restart count
docker inspect frc-proxies-proxyv2 2>/dev/null | jq '.[0] | {status:.State.Status, restarts:.RestartCount}'
```

### 2. ECE Proxy Ports
| Port | Service | Protocol |
|---|---|---|
| 9200 | ES HTTP (via proxy) | HTTP |
| 9243 | ES HTTPS (via proxy) | HTTPS |
| 9300 | ES transport (CCS/CCR) | TLS |
| 9343 | ES transport TLS | TLS |
| 5601 | Kibana HTTP | HTTP |
| 5602 | Kibana HTTPS | HTTPS |

```bash
# Test proxy ports
for PORT in 9200 9243 5601 5602 9300; do
  nc -z localhost $PORT && echo "Port $PORT: OK" || echo "Port $PORT: FAIL"
done
```

### 3. Proxy Logs — Error Analysis
```bash
docker logs frc-proxies-proxyv2 --tail 100 2>&1 | grep -E "ERROR|WARN|failed|backend|route|refused|timeout" | tail -30
```
Key proxy error patterns:
- `No route found for cluster` → route server doesn't have routing info for the deployment
- `Backend connection refused` → ES/Kibana instance on allocator is not running
- `Backend timeout` → instance is running but not responding (GC pause, OOM)
- `TLS handshake failed` → cert issue between proxy and backend instance

### 4. Route Server Status
```bash
docker ps --filter "name=frc-route-servers" --format "{{.Names}}\t{{.Status}}"
docker logs frc-route-servers-route-server --tail 50 2>&1 | grep -E "ERROR|WARN|route|update|ZooKeeper" | tail -20
```
The route server distributes routing information from ZooKeeper to proxies. If the route server is down, proxies use stale routing tables.

### 5. Routing Table Verification
```bash
# Check routing info for a specific deployment via proxy API (if available)
curl -s -k https://localhost:9243/_cluster/name 2>/dev/null | head -5

# Check if the cluster's endpoint is configured in ECE
curl -s -k -u admin:<password> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>" | \
  jq '.metadata.endpoint'
```

### 6. Proxy-to-Instance Connectivity
When the proxy receives a request, it routes to the ES/Kibana container on an allocator:
```bash
# Check if the instance container is running on the allocator
docker ps --filter "label=com.elastic.cluster.id=<cluster-id>" --format "{{.Names}}\t{{.Status}}"

# Test direct connectivity from proxy host to instance port
docker inspect <instance-container> | jq '.[0].NetworkSettings.IPAddress'
curl -s http://<instance-ip>:9200/_cluster/health | jq '.status'
```

### 7. Traffic During Plan Changes
During a rolling restart, the proxy temporarily stops routing to nodes being restarted:
- For single-node deployments: brief outage during restart is expected
- For multi-node: traffic should shift to other nodes

Check if a plan change is in progress:
```bash
curl -s -k -u admin:<password> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>" | \
  jq '.plan_info.pending | {pending:.plan_attempt_id}'
```

### 8. CCS/CCR Port Issues
Cross-cluster search (CCS) and replication (CCR) use port 9300 (transport):
```bash
nc -z <ece-proxy-host> 9300 && echo "Transport port OK" || echo "Transport port FAIL"
nc -z <ece-proxy-host> 9343 && echo "Transport TLS port OK" || echo "Transport TLS port FAIL"
```
Firewall blocking port 9300/9343 = CCS/CCR fails even if regular ES access works.

### 9. Proxy Configuration Reload
After routing table updates (e.g., after a new deployment is created), the proxy should pick up new routes automatically. If routes are stale:
```bash
# Check when proxy last updated routing
docker logs frc-proxies-proxyv2 --since 10m 2>&1 | grep -E "route.*update|reload|refresh" | tail -5

# Restart proxy if routes are not updating (use caution — causes brief traffic interruption)
docker restart frc-proxies-proxyv2
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific proxy error message and whether the deployment is in a plan change.

## Token Budget
- Port test with `nc` and proxy logs give instant diagnosis.
- Check route server before proxy — routes may be stale, not proxy broken.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
