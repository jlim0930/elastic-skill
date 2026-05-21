---
name: ece-coordinator-admin-console
description: Diagnoses ECE coordinator and admin console issues including cannot log into admin console, Cloud UI unavailable, admin console Elasticsearch unhealthy, constructor/admin-console service failures, API/UI mismatch, coordinator port/connectivity issues, and platform changes blocked by unhealthy coordinator services.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE — Coordinator / Admin Console Sub-Agent

Scope: Cannot log into admin console, Cloud UI unavailable, admin console ES unhealthy, constructor/admin-console service failures, API/UI mismatch, coordinator port/connectivity, platform changes blocked by unhealthy coordinator services.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE admin console unavailable"`, `"ECE Cloud UI login failed"`, `"ECE coordinator service failure"`, `"ECE constructor blocked"`, `"ECE admin console elasticsearch unhealthy"`.

## Diagnostic Steps

### 1. Admin Console Container Status
```bash
# Coordinator containers
docker ps --filter "name=frc-coordinators" --format "{{.Names}}\t{{.Status}}"
docker ps --filter "name=frc-admin-console" --format "{{.Names}}\t{{.Status}}"
docker ps --filter "name=frc-constructors" --format "{{.Names}}\t{{.Status}}"

# Port availability
nc -z localhost 12400 && echo "UI port 12400 OK" || echo "UI port 12400 FAIL"
nc -z localhost 12443 && echo "API port 12443 OK" || echo "API port 12443 FAIL"
```

### 2. Test Admin Console API
```bash
# Test API without auth (should return 401, not connection error)
curl -s -k -o /dev/null -w "%{http_code}" https://localhost:12443/api/v1/platform

# Test with credentials
curl -s -k -u admin:<password> https://localhost:12443/api/v1/platform | jq '.version'
```
- 200 = API healthy
- 401 = API running but wrong credentials
- Connection refused = coordinator service down
- 502/503 = coordinator running but internal error

### 3. Coordinator Logs
```bash
docker logs frc-coordinators-coordinator --tail 100 2>&1 | grep -E "ERROR|FATAL|startup|failed|exception" | tail -30
```
Common coordinator errors:
- `Cannot connect to admin-console-elasticsearch` → admin console ES is down
- `Authentication service unavailable` → security cluster issue
- `ZooKeeper connection failed` → director/ZK issue (see `director-zookeeper.md`)
- `Port already in use` → port conflict on coordinator host

### 4. Admin Console Elasticsearch Health
The admin console is backed by a dedicated ES deployment (`admin-console-elasticsearch`):
```bash
# Check admin console ES cluster health via API
curl -s -k -u admin:<password> https://localhost:12443/api/v1/clusters/elasticsearch | \
  jq '[.elasticsearch_clusters[] | select(.cluster_name | test("admin-console")) | {name:.cluster_name, status:.status}]'

# Check if admin-console-elasticsearch containers are running on allocators
docker ps --filter "label=com.elastic.cluster.type=admin-console-elasticsearch" --format "{{.Names}}\t{{.Status}}"
```
If admin-console-elasticsearch is red/unhealthy: see `system-deployments.md` for diagnosis.

### 5. Cannot Log In to Admin Console
If the UI loads but login fails:
1. Verify credentials — admin password is set during ECE installation
2. Check if the security cluster is healthy (authentication backend):
   ```bash
   curl -s -k -u admin:<password> https://localhost:12443/api/v1/clusters/elasticsearch | \
     jq '[.elasticsearch_clusters[] | select(.cluster_name | test("security")) | {name:.cluster_name, status:.status}]'
   ```
3. If security cluster is red: see `system-deployments.md`

Reset admin password:
```bash
curl -s -k -XPOST -u admin:<old-password> https://localhost:12443/api/v1/users/admin/_password \
  -H "Content-Type: application/json" \
  -d '{"password": "<new-password>"}' | jq '.'
```

### 6. Constructor Service Failures
The constructor orchestrates plan changes. If it's unhealthy, no plan changes can proceed:
```bash
docker logs frc-constructors-constructor --tail 50 2>&1 | grep -E "ERROR|FATAL|failed|exception" | tail -20

# Constructor status via API
curl -s -k -u admin:<password> https://localhost:12443/api/v1/platform/infrastructure/constructors | jq '.'
```

### 7. API/UI Mismatch
If the UI shows different information than the API:
```bash
# Compare what UI shows vs API
curl -s -k -u admin:<password> "https://localhost:12443/api/v1/clusters/elasticsearch/<cluster-id>" | jq '{status:.status, plan:.plan_info.current.plan_attempt_log[-1]}'
```
API is authoritative. UI caches data — hard refresh the browser (Ctrl+Shift+R) before concluding there's a mismatch.

### 8. Coordinator Port Conflicts
```bash
# Check what is using ECE ports
ss -tlnp | grep -E "12400|12443|9200|9243|9300"
lsof -i :12400 -i :12443 2>/dev/null | head -10
```
If ECE ports are used by another process: stop the conflicting process and restart ECE coordinator.

### 9. Restart Coordinator Services
```bash
# Restart coordinator container (use with caution in production)
docker restart frc-coordinators-coordinator

# Or restart all ECE services on the host
bash /mnt/data/elastic/scripts/elastic-cloud-enterprise.sh restart
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific coordinator error (from logs or HTTP status) and the ECE version.

## Token Budget
- `docker ps` + `curl` API test give instant coordinator status.
- Check admin-console-elasticsearch health before investigating coordinator itself.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
