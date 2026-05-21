---
name: ece-director-zookeeper
description: Diagnoses ECE Director and ZooKeeper issues including directors down, ZooKeeper quorum loss, leader election failures, director communication failures, platform state inconsistency, TLS tunnel/client forwarder issues, and loss of HA due to director failures.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE — Director / ZooKeeper Sub-Agent

Scope: Directors down, ZooKeeper quorum loss, leader election failures, director communication failures, platform state inconsistency, TLS tunnel/client forwarder issues to ZooKeeper, HA loss from director failures.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE ZooKeeper quorum loss"`, `"ECE director down"`, `"ECE leader election failed"`, `"ECE platform state inconsistency"`, `"ECE ZooKeeper TLS tunnel"`.

## Diagnostic Steps

### 1. Director and ZooKeeper Container Status
```bash
# On each coordinator/director host
docker ps --filter "name=frc-directors" --format "{{.Names}}\t{{.Status}}\t{{.Ports}}"
docker ps --filter "name=frc-zookeeper" --format "{{.Names}}\t{{.Status}}\t{{.Ports}}"

# Restart counts
docker inspect frc-directors-director 2>/dev/null | jq '.[0] | {status:.State.Status, restarts:.RestartCount, started:.State.StartedAt}'
```

### 2. ZooKeeper Quorum Status
```bash
# Check ZooKeeper quorum — must have majority of nodes (2 of 3, 3 of 5)
docker exec frc-zookeeper-0 bash -c "echo stat | nc localhost 2181" 2>/dev/null | grep -E "Mode|Clients|Outstanding|Latency"

# Alternative: check all ZK nodes
for ZK in frc-zookeeper-0 frc-zookeeper-1 frc-zookeeper-2; do
  echo "=== $ZK ==="; docker exec $ZK bash -c "echo stat | nc localhost 2181" 2>/dev/null | grep -E "Mode|Zxid"; done
```
Expected output: one node shows `Mode: leader`, others show `Mode: follower`.
If all show `Mode: looking` → quorum lost. If some ZK containers are down → check quorum math.

### 3. ZooKeeper Quorum Requirements
| Total ZK nodes | Nodes needed for quorum |
|---|---|
| 3 (1 per coordinator) | 2 of 3 |
| 5 | 3 of 5 |

If quorum is lost, the platform cannot make state changes. Deployments may still serve traffic through the proxy, but no new plan changes, scaling, or configuration changes are possible.

### 4. Director Logs — ZooKeeper Connectivity
```bash
docker logs frc-directors-director --tail 100 2>&1 | grep -E "ZooKeeper|quorum|leader|ConnectionLoss|SessionExpired|WARN|ERROR" | tail -30
```
Key error patterns:
- `ConnectionLoss` → director cannot reach ZooKeeper
- `SessionExpired` → ZooKeeper session expired (director was disconnected too long)
- `leader election` → quorum is trying to elect a new leader
- `Waiting for ZooKeeper quorum` → platform is paused waiting for quorum

### 5. Client Forwarder / TLS Tunnel
ECE uses TLS tunnels for communication between platform components and ZooKeeper:
```bash
# Check client forwarder container
docker ps --filter "name=frc-client-forwarders" --format "{{.Names}}\t{{.Status}}"
docker logs frc-client-forwarders-client-forwarder --tail 50 2>&1 | grep -E "ERROR|WARN|tunnel|TLS|connect"
```
TLS tunnel failures prevent directors on remote hosts from connecting to ZooKeeper on coordinator hosts.

### 6. Director Communication Failures
```bash
# Check if directors on remote hosts can reach coordinator
docker logs frc-directors-director --tail 50 2>&1 | grep -E "connect|unreachable|timeout|refused" | tail -10

# Network connectivity test from allocator/proxy host to coordinator ZK port
nc -z <coordinator-ip> 2181 && echo "ZK port open" || echo "ZK port blocked"
nc -z <coordinator-ip> 2888 && echo "ZK peer port open" || echo "ZK peer port blocked"
nc -z <coordinator-ip> 3888 && echo "ZK election port open" || echo "ZK election port blocked"
```
ZooKeeper ports: 2181 (client), 2888 (peer), 3888 (election).

### 7. Platform State Inconsistency
After ZooKeeper quorum loss and recovery, platform state may be inconsistent:
```bash
# Check if deployments in ECE API match actual running containers
curl -s -k -u admin:<pass> https://localhost:12443/api/v1/clusters/elasticsearch | jq '[.elasticsearch_clusters[] | {id:.cluster_id, status:.status}]' | head -20

# Compare with actual running containers on allocators
docker ps --filter "label=com.elastic.cluster.id" --format "{{.Label \"com.elastic.cluster.id\"}}\t{{.Names}}" | head -20
```

### 8. Recovering ZooKeeper Quorum
If ZK quorum is lost and cannot recover automatically:
1. Identify which ZK nodes are down (container stopped, host failed)
2. Restart the ZK container on the affected host if the host is healthy:
   ```bash
   docker restart frc-zookeeper-0
   ```
3. If the host is permanently lost, ZK quorum requires at least `(total_nodes / 2) + 1` nodes
4. Contact Elastic Support for ZK data recovery if quorum cannot be established

### 9. HA Loss from Director Failures
ECE HA requires all coordinator hosts to be healthy. If one coordinator fails:
- ZooKeeper quorum may still hold (2 of 3 remaining)
- Platform can still operate but HA is reduced
- Restart the failed coordinator's platform services

```bash
# Restart all ECE services on a host
bash /mnt/data/elastic/scripts/elastic-cloud-enterprise.sh start
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the ZK error (quorum loss, connection loss, session expired) and the number of coordinator hosts.

## Token Budget
- ZK `stat` command gives instant quorum status.
- `docker ps` for director/ZK container status before reading logs.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
