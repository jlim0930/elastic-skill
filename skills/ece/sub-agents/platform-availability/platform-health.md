---
name: ece-platform-health
description: Diagnoses ECE platform-wide health and availability issues including ECE UI unavailable, admin console inaccessible, platform API unavailable, system-wide degradation, deployment endpoints not responsive, platform services restarting or unhealthy, and distinguishing platform outage from deployment outage.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE — Platform Health & Availability Sub-Agent

Scope: ECE UI unavailable, admin console inaccessible, platform API unavailable, system-wide degradation, deployment endpoints not responsive, platform services restarting/unhealthy, platform vs deployment outage distinction.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE platform unavailable"`, `"ECE admin console down"`, `"ECE system-wide degradation"`, `"ECE deployment endpoints not responding"`, `"ECE platform vs deployment outage"`.

## Diagnostic Steps

### 1. Quick Platform Status Triage
```bash
# Check ECE API availability (coordinator host)
curl -s -k https://localhost:12443/api/v1/platform | jq '.version'

# Check if admin console UI port is responding
curl -s -k -o /dev/null -w "%{http_code}" https://localhost:12400

# List running ECE containers on coordinator
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "frc-|runner|director|coordinator|proxy|zookeeper"
```

### 2. ECE Platform Service Overview
Key platform services and their containers:

| Service | Container prefix | Role |
|---|---|---|
| Director | `frc-directors-director` | ZooKeeper/platform state |
| Coordinator | `frc-coordinators-coordinator` | Admin console API |
| Admin console ES | `frc-admin-console-elasticsearch-*` | Backs admin UI |
| Constructor | `frc-constructors-constructor` | Plan orchestration |
| Proxy | `frc-proxies-proxyv2` | Traffic routing |
| Route server | `frc-route-servers-route-server` | Routing table |
| Beats | `frc-beats-runner-*` | Platform monitoring |
| Zookeeper | `frc-zookeeper-*` | Distributed state |

### 3. Platform vs. Deployment Outage
```
Platform outage indicators:
  ✓ Admin console UI completely unreachable (no HTTP response)
  ✓ Multiple deployments across different allocators simultaneously affected
  ✓ ECE API (port 12443) not responding
  ✓ Director/ZooKeeper containers down on coordinator hosts
  ✓ No new plan changes can be initiated for any deployment

Deployment-only outage indicators:
  ✓ Admin console UI accessible
  ✓ ECE API responds normally
  ✓ Only specific deployment(s) affected
  ✓ Other deployments on same platform are healthy
  ✓ Allocators and proxies are healthy
```

### 4. Check Platform Services on All Coordinators
```bash
# On each coordinator host
docker ps --filter "name=frc-" --format "{{.Names}}\t{{.Status}}" | sort

# Check for recently restarted containers
docker ps --filter "name=frc-" --format "{{.Names}}\t{{.Status}}" | grep -v "Up [0-9]* [a-z]*s ago" | grep -v "Up [1-9][0-9]* days"

# Container logs for errors
docker logs frc-coordinators-coordinator --tail 50 2>&1 | grep -E "ERROR|FATAL|error|failed"
```

### 5. Platform API Health Check
```bash
# Full platform info
curl -s -k -u admin:<password> https://localhost:12443/api/v1/platform | jq '{version:.version, date:.build_date}'

# Platform cluster health
curl -s -k -u admin:<password> https://localhost:12443/api/v1/clusters/elasticsearch?include_hidden=true | jq '.elasticsearch_clusters | length'
```

### 6. Identify Which Platform Role Is Failing
Run diagnostics on each role:
```bash
# Directors — ZooKeeper state
docker logs frc-directors-director --tail 30 2>&1 | grep -E "ERROR|WARN|ZooKeeper|quorum|leader"

# Coordinator — API/UI
docker logs frc-coordinators-coordinator --tail 30 2>&1 | grep -E "ERROR|FATAL|startup|failed"

# Proxy — traffic routing
docker logs frc-proxies-proxyv2 --tail 30 2>&1 | grep -E "ERROR|route|backend"
```
Each role has a dedicated sub-agent — route to the specific sub-agent once the failing role is identified.

### 7. Deployment Endpoint Responsiveness
If deployment endpoints are not responding but the platform is up:
```bash
# Check proxy container
docker ps --filter "name=frc-proxies" --format "{{.Names}}\t{{.Status}}"

# Test proxy port
nc -z localhost 9200 && echo "ES proxy port OK" || echo "ES proxy port FAIL"
nc -z localhost 9243 && echo "ES SSL proxy port OK" || echo "ES SSL proxy port FAIL"
```
See `proxy-routing.md` for detailed proxy diagnosis.

### 8. Platform Restart Loop Detection
```bash
# Check restart count for platform containers
docker inspect frc-coordinators-coordinator | jq '.[0].RestartCount'
docker inspect frc-directors-director | jq '.[0].RestartCount'
docker inspect frc-proxies-proxyv2 | jq '.[0].RestartCount'
```
RestartCount > 3 = container is crash-looping. Check logs for the crash cause.

### 9. KCS + Docs Lookup
Execute retrieval protocol with the specific platform service that is failing and the error from its container logs.

## Token Budget
- `docker ps` gives instant service status across all platform roles.
- Route to the specific role sub-agent as soon as the failing service is identified.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
