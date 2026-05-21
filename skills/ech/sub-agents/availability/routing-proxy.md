---
name: ech-routing-proxy
description: Diagnoses ECH proxy and routing issues including requests failing through the cloud proxy, proxy routing blocks during plan changes, "stop routing requests" behavior, traffic still reaching unhealthy instances, proxy-related 502/connection failures, endpoint routing confusion, and routing impact on Kibana and APM availability.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECH — Routing & Proxy Sub-Agent

Scope: Requests failing through cloud proxy, proxy routing blocks during plan changes, "stop routing requests" behavior, 502/503/504 from proxy, traffic reaching unhealthy instances, Elasticsearch endpoint vs direct instance behavior, routing impact on Kibana/APM availability.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECH proxy 502 error"`, `"Elastic Cloud stop routing requests"`, `"ECH proxy connection failed"`, `"Elastic Cloud endpoint routing"`, `"ECH proxy plan change traffic"`, `"Elastic Cloud proxy unhealthy backend"`.

## Diagnostic Steps

### 1. Identify the Proxy Error Type
ECH places a managed proxy (route server / forwarder) in front of all hosted instances. All client traffic passes through this proxy — there is no direct instance access.

| HTTP status from proxy | Meaning | Next step |
|---|---|---|
| `502 Bad Gateway` | Proxy reached the backend but got no valid HTTP response | Backend instance crashed or is starting up |
| `503 Service Unavailable` | Proxy has no healthy backends to route to | All instances in this deployment are unhealthy |
| `504 Gateway Timeout` | Backend responded too slowly | Large query, GC pause, or ES thread pool exhausted |
| Connection refused | Client cannot reach the proxy endpoint | DNS, firewall, or endpoint URL wrong — see `network-access.md` |
| Connection timeout | TCP connection to proxy not completing | Firewall or network issue between client and ECH — see `network-access.md` |

### 2. During Plan Changes — "Stop Routing Requests" Behavior
During rolling restarts (plan changes), the ECH proxy stops routing to nodes being restarted:
- Traffic is redirected to remaining healthy nodes while one node restarts
- If the deployment has only **1 node**: traffic is fully interrupted during the restart window (expected behavior)
- This is by design — the proxy prevents traffic from hitting nodes that are not yet ready

How to tell if this is a plan change pause vs. a real failure:
```
Deployments → [Deployment] → Activity → look for "in-progress" or "rolling_restart" step
```
If a plan is in progress and requests are failing: wait for the rolling restart to complete (each node takes 1-5 minutes).

### 3. Proxy Routing to Unhealthy Instances
The ECH proxy uses health checks to determine which instances to route to. After an instance fails:
- There is a brief window (health check interval) where traffic may still hit the newly-unhealthy instance
- Persistent routing to an unhealthy instance = proxy health check is not detecting the failure

```bash
# Verify which nodes are actually healthy
GET _cat/nodes?v&h=name,heap.percent,cpu,node.role,master

# Check cluster health
GET _cluster/health | jq '{status:.status, nodes:.number_of_nodes, relocating:.relocating_shards}'
```

### 4. Verify Endpoint Correctness
Each ECH resource type has its own endpoint. Using the wrong endpoint is a common cause of routing confusion:
```
Elasticsearch: https://<deployment-name>.es.<region>.<provider>.elastic-cloud.com:443
Kibana:        https://<deployment-name>.kb.<region>.<provider>.elastic-cloud.com:443
APM Server:    https://<deployment-name>.apm.<region>.<provider>.elastic-cloud.com:443
Fleet Server:  https://<deployment-name>.fleet.<region>.<provider>.elastic-cloud.com:443
Enterprise Search: https://<deployment-name>.ent.<region>.<provider>.elastic-cloud.com:443
```
- All ECH endpoints use **port 443** (HTTPS only). Never use port 9200 for ECH.
- Using a `.es.` endpoint for Kibana (or vice versa) causes routing failures.

### 5. Test Proxy Connectivity
```bash
# Test ES proxy endpoint
curl -sv "https://<es-endpoint>:443" 2>&1 | grep -E "Connected|SSL|HTTP|< "

# Test with credentials and a timeout to detect proxy vs. backend timeout
curl --max-time 10 -s -u <user>:<pass> "https://<es-endpoint>:443/_cluster/health" | jq '.status'

# Identify where the failure occurs
curl -sv "https://<es-endpoint>:443/_cluster/health" 2>&1 | grep -E "< HTTP/|Connected to|SSL handshake|timeout"
```

### 6. Proxy-Related 502 During Normal Operation (No Plan Change)
502 during normal operation (no plan change in progress) indicates the backend instance crashed:
- JVM OOM crash: check logs for `OutOfMemoryError` or `java.lang.OutOfMemoryError`
- Elasticsearch process killed by OS OOM killer (check `dmesg` — not available in ECH, but OOM-related log patterns are visible)
- Platform-level issue: hypervisor or network between proxy and backend

```bash
# Check if cluster recovered after 502
curl -s -u <user>:<pass> "https://<es-endpoint>/_cluster/health" | jq '{status:.status, nodes:.number_of_nodes}'

# Check cluster logs for crash pattern
# In Deployments → Logs and metrics → search for: OutOfMemoryError OR "killed process"
```

### 7. Routing Impact on Kibana Availability
Kibana in ECH uses the same proxy infrastructure as Elasticsearch. However, Kibana and ES have separate proxy routes:

**Kibana is unavailable but ES is healthy:**
- Kibana instance itself may have crashed (check Kibana instance health in console)
- Verify the client is using the `.kb.` endpoint, not the `.es.` endpoint
- Kibana can be restarted independently via ECH console

**ES is unavailable (502/503) and Kibana shows "Server is not ready yet":**
- This is a cascade — Kibana cannot function without ES
- Fix the ES routing/health issue first; Kibana will recover automatically

```bash
# Test Kibana endpoint independently
curl -sv "https://<kb-endpoint>:443" 2>&1 | grep -E "< HTTP|Connected|SSL"
```

### 8. Routing Impact on APM Availability
APM Server in ECH has its own proxy route and endpoint:
```bash
# Test APM Server health
curl -s "https://<apm-endpoint>:443/" | jq '{ok:.ok, version:.version}'

# APM agents send to this endpoint — verify the endpoint in agent config matches
```
APM Server connects to Elasticsearch to store data. If ES is unhealthy, APM Server may continue accepting data but fail to index it.

### 9. Proxy Behavior with Private Connectivity
If using AWS PrivateLink / Azure Private Link / GCP PSC:
- Traffic routes through the cloud provider private endpoint to the ECH proxy
- The ECH proxy then routes internally to the ES/Kibana/APM instances
- The proxy-level behavior (502, 503, routing, health checks) is the same regardless of public vs. private connectivity

Verify private DNS resolves to a private IP:
```bash
dig <es-endpoint> +short  # Should return 10.x.x.x or similar private IP
```

See `private-connectivity.md` for private endpoint setup issues.

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific HTTP error code (502/503/504), the endpoint type (ES/Kibana/APM/Fleet), and whether a plan change was in progress at the time.

## Token Budget
- `curl` to the endpoint with `-sv` gives instant proxy path information.
- Check plan change activity before any log analysis.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
