---
name: ece-container-runtime
description: Diagnoses ECE Docker/Podman container runtime failures, crash loops, image pull errors, cgroup limits, and OS-level issues affecting the Elastic Stack on ECE.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE Container Runtime Sub-Agent

Scope: Docker/Podman daemon failures, container crash loops, image pull errors, cgroup resource limits, OS OOM, ulimit violations, inode exhaustion.

## Retrieval Protocol
Follow [../../../shared/retrieval-protocol.md](../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE Docker daemon failed"`, `"ECE container CrashLoop"`, `"ECE Podman rootless cgroup"`.

## Diagnostic Steps

### 1. Container Status
```bash
docker ps -a   # or: podman ps -a
```
Look for `Exited`, `Restarting`, or missing containers.
For crash loops: `docker inspect <container> | jq '.[0].State'` — check `ExitCode` and `OOMKilled`.

### 2. Container Logs
```bash
docker logs <container> --tail 200 2>&1 | grep -E "ERROR|WARN|Fatal|Exception|killed|OOM"
```
Common fatal patterns:
- `Java heap space` → JVM OOM → check heap settings.
- `Native memory allocation failed` → OS-level memory exhaustion.
- `no space left on device` → disk full.
- `too many open files` → `nofile` ulimit too low.

### 3. Docker / Podman Daemon Health
```bash
systemctl status docker   # or: systemctl status podman
journalctl -u docker -n 100 --no-pager
```
Daemon crashes affect ALL containers on the host simultaneously. If multiple containers fail at the same time → check daemon logs first.

### 4. OS Resource Checks
```bash
df -h /data/elastic          # disk space
df -i /data/elastic          # inodes
free -m                      # memory
dmesg | grep -E "OOM|oom_kill|killed process" | tail -20
ulimit -a                    # current limits (run as ECE service user)
cat /proc/sys/vm/max_map_count  # must be >= 262144 for Elasticsearch
```

### 5. cgroup Limits
```bash
cat /sys/fs/cgroup/memory/docker/<container-id>/memory.limit_in_bytes
cat /sys/fs/cgroup/memory/docker/<container-id>/memory.usage_in_bytes
```
If usage equals limit → container is at cgroup memory cap → OOM possible.

### 6. Image Pull Failures
```bash
docker pull <image>   # test manually
docker images | grep elastic  # check local image presence
```
Image pull failures cause new instance deployments to fail silently. Check Docker registry connectivity and credentials.

### 7. KCS + Docs Lookup
Execute retrieval protocol now. Query with the container exit code or OS error message.

## Token Budget
- Use `grep` to filter container logs before reading; never load full logs.
- `dmesg | grep OOM | tail -20` only — do not load full dmesg.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../shared/output-format.md](../../../shared/output-format.md).
Reference thresholds from [../../../shared/thresholds.md](../../../shared/thresholds.md).
