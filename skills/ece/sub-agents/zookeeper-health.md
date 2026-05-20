---
name: ece-zookeeper-health
description: Diagnoses ECE ZooKeeper instability including leader election failures, connection loss, and control-plane disruption.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE ZooKeeper Health Sub-Agent

Scope: ZooKeeper leader election failures, `CONNECTION_LOSS`, `SessionExpiredException`, control-plane disruption, director failures.

## Retrieval Protocol
Follow [../../../shared/retrieval-protocol.md](../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE ZooKeeper leader election failed"`, `"ECE ZooKeeper CONNECTION_LOSS"`, `"ECE director ZooKeeper quorum"`.

## Diagnostic Steps

### 1. ZooKeeper Connectivity
Run from each director host:
```bash
echo ruok | nc <zk-host> 2181   # expect: imok
echo mntr | nc <zk-host> 2181   # check: zk_server_state, zk_outstanding_requests
echo stat | nc <zk-host> 2181   # check leader/follower/observer status
```
Key `mntr` metrics:
- `zk_server_state: leader` → this node is the ZK leader.
- `zk_outstanding_requests > 10` sustained = ZK overloaded.
- `zk_avg_latency > 10ms` = performance degradation.

### 2. ZooKeeper Quorum
ECE requires a majority of ZK nodes to form quorum:
- 1 director: no quorum tolerance.
- 3 directors: tolerates 1 failure.
- 5 directors: tolerates 2 failures.
Check all director nodes are reachable: `ping` / `nc -zv <host> 2181`.

### 3. ZooKeeper Logs
```bash
grep -E "WARN|ERROR|Exception|leader\|election\|CONNECTION_LOSS|SessionExpired" /data/elastic/logs/director.log | tail -100
```
- `SessionExpiredException` → client lost ZK connection; director may be restarting.
- `leader is not a follower` → split-brain signal.
- `Unable to load database` → ZK data directory corruption (critical).

### 4. Director Health
```bash
docker logs frc-directors --tail 200
```
or
```bash
podman logs frc-directors --tail 200
```
Director is the ECE control-plane service that uses ZK for coordination. Director restarts = plan disruptions.

### 5. ZK Snapshot / Log Files
If ZK data directory is corrupt:
- Do NOT delete data without ECE support guidance.
- ZK data path: `/data/elastic/zookeeper/` (default).
- Check inode and disk space: `df -i /data/elastic/zookeeper`.

### 6. KCS + Docs Lookup
Execute retrieval protocol now. Query with the specific ZK exception and ECE version.

## Token Budget
- Extract last 100 lines from director/ZK logs only; do not load full log files.
- `grep` for exception names before reading context lines.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../shared/output-format.md](../../../shared/output-format.md).
Reference thresholds from [../../../shared/thresholds.md](../../../shared/thresholds.md).
