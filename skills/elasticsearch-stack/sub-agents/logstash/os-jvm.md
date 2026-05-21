---
name: ls-os-jvm
description: Diagnoses Logstash JVM heap pressure, GC pauses, OutOfMemoryError, file handle exhaustion, container memory limit mismatch causing OOM kills, disk space issues for PQ and temp files, service startup failures, and permission issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# LS — OS / JVM

**Purpose**: Identify whether Logstash performance or startup issues stem from JVM heap, GC, OS limits, or permissions, and prescribe the fix.

## Use When
- Logstash process killed without warning (OOM kill)
- GC pauses causing throughput drops across all pipelines
- Service fails to start with permission errors
- File descriptor exhaustion

## Do Not Use When
- Pipeline-level performance issues without JVM pressure → logstash/pipeline-throughput-performance
- Config parsing errors on startup → logstash/pipeline-startup-config

## Inputs Needed
- JVM heap % from Node Stats API (`localhost:9600/_node/stats/jvm`)
- GC old collection count and time
- Container memory limit if running in Docker/Kubernetes
- OS file descriptor limit (`ulimit -n`)

## Diagnostic Logic

### JVM Heap Thresholds
- > 75% = Warning — GC pressure building
- > 85% = Critical — throughput impact across all pipelines
- > 90% = Emergency — OOM imminent; reduce `pipeline.batch.size` immediately

### Heap Sizing Rules
- Set `Xms` = `Xmx` (prevents heap resize pauses)
- Recommended: 4–8 GB for typical workloads; above ~6 GB, GC overhead increases
- Leave ≥ 25% of RAM for OS page cache (used by PQ disk I/O)
- JRuby causes higher object churn than standard Java — GC pressure is expected to be higher

### OOM Kill vs JVM OOM Error
| Symptom | Cause | Check |
|---|---|---|
| Process disappears, no JVM log | OS OOM kill (`kill -9` by kernel) | `dmesg | grep oom` or `journalctl -k | grep oom` |
| `OutOfMemoryError` in Logstash log | JVM heap exhausted | Heap settings + `hs_err_pid*.log` |
| Container restarts suddenly | Pod memory limit exceeded | `kubectl describe pod` for OOMKilled reason |

### Container Memory Limits
- JVM heap (`-Xmx`) must be ≤ 75% of container memory limit
- Example: 4 GB container → max `-Xmx3g`
- If `-Xmx` exceeds container limit → OS OOM kill; no JVM error logged; process just disappears
- Set `LS_JAVA_OPTS: "-Xms4g -Xmx4g"` in container env; ensure limit allows it

### GC Pressure
- Old GC count growing rapidly = heap too small or too many large objects retained
- GC pauses slow ALL pipelines simultaneously — not just one
- Fix: increase heap (within container/host RAM limit); reduce `pipeline.batch.size`
- G1GC is recommended for large heaps — verify it's set in `jvm.options`

### File Descriptor Limits
- > 80% of max open FDs = Warning
- Logstash needs FDs for: PQ page files, log files, network sockets per connection
- Minimum required: 65535 (`LimitNOFILE=65535` in systemd unit override)
- After changing limit: restart Logstash and verify `/proc/<pid>/limits`

### Disk Space Issues
- PQ path full → PQ stops accepting events → input blocked
- Log path full → log rotation fails → startup errors
- `/tmp` full → temp file operations fail in some filters
- Monitor all three: PQ path, log path, `/tmp`

### Service Startup / Permissions
- Logstash must own and write: data dir (`/var/lib/logstash`), log dir (`/var/log/logstash`), queue path
- `Permission denied` on startup → check ownership of these directories
- Fix: `chown -R logstash:logstash /var/lib/logstash /var/log/logstash`
- Systemd startup order: if Logstash starts before network is ready, CPM connectivity fails; add `After=network-online.target`

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for OOM, GC, permission denied patterns

## KCS Queries
`"logstash heap GC pressure OutOfMemoryError"`, `"logstash OOM kill container memory limit"`, `"logstash file descriptor limit exhausted"`, `"logstash startup permission denied"`

## Output
Report: heap %, GC pressure severity, OOM type (JVM vs OS kill), file descriptor or disk issue, fix.
