---
name: ls-input-connectivity
description: Diagnoses Logstash Kafka input lag and fetch failures, Beats input connection issues, syslog/TCP/UDP listener bind failures, file input not tailing correctly with sincedb issues, JDBC input scheduling and state file problems, and cloud/network/firewall interruptions affecting inputs.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# LS — Input Connectivity

**Purpose**: Identify why a Logstash input is not receiving events and prescribe the fix.

## Use When
- `events.in` = 0 for a pipeline despite sources sending data
- Input plugin errors in logs (bind failure, connection refused, SSL)
- File input not tailing or missing data
- JDBC or Kafka consumer not fetching

## Do Not Use When
- Events arriving but being dropped → logstash/event-loss-delivery
- TLS error on Beats input → logstash/tls-certificates
- Pipeline not starting → logstash/pipeline-startup-config

## Inputs Needed
- Input plugin type (Beats, Kafka, file, syslog, JDBC)
- `events.in` count from Node Stats API
- Error message from `logstash-plain.log`
- Port or file path configured

## Diagnostic Logic

### First Check
- `events.in` = 0 for extended period → input not receiving data
- Check that the input port is bound: verify port is listening before checking config

### Beats Input Issues
| Issue | Error | Fix |
|---|---|---|
| Port not bound | `BindException: Address already in use` | Find conflicting process on port 5044 |
| TLS mismatch | `SSLHandshakeException` | Verify cert/key in Beats input; check CA |
| Client rejected | `SSL peer closed inbound` | Beats not sending cert when `required` mode active |
| Beats can't connect | `connection refused` | Firewall blocking port 5044 from Beats host |

### Kafka Input Issues
- `events.in` = 0 + Kafka input → consumer not assigned partitions, or no new messages
- `auto.offset.reset: latest` after restart → events during downtime skipped (not fetched)
- Consumer group not assigned: another consumer in same group has all partitions → check `group_id` uniqueness
- SASL/TLS mismatch with broker → check `security_protocol` and `sasl_mechanism` settings

### Syslog / TCP / UDP Issues
- `BindException: Address already in use` → another process already on that port
- `Permission denied` on ports < 1024 → run as root or use `authbind`
- Test connectivity from source to Logstash to isolate firewall vs bind issues

### File Input — sincedb
- File input tracks read position via sincedb file (keyed by inode + size + mtime)
- `path` glob doesn't match → file not discovered (verify with `ls <glob>`)
- sincedb position at file size → Logstash considers file fully read (no new reads)
- Log rotation changed inode → old inode in sincedb, new file treated as unread
- To re-read from beginning: delete the relevant sincedb entry for that file

### File Input Common Problems
| Problem | Cause | Fix |
|---|---|---|
| File not discovered | `path` glob doesn't match | Verify glob with `ls` |
| Old data re-read after rotation | Log rotation changed inode | Configure `file_completed_action` |
| New data ignored | sincedb position at EOF | Clear sincedb entry |
| Rotated files missed | `stat_interval` too long | Reduce `stat_interval` |

### JDBC Input Issues
- Missing or wrong JAR version → `ClassNotFoundException: <driver_class>`
- State file (`last_run_metadata`) tracks `tracking_column` value — stale or corrupt file → missed/duplicate rows
- Clear state file (full reload on next run): delete the `last_run_metadata_<hash>` file
- Verify JDBC driver JAR path exists and is readable

## Shared Skills
→ [network_connectivity_checks](../../../../shared/network_connectivity_checks.md) — port reachability, firewall, DNS for input sources
→ [tls_certificate_checks](../../../../shared/tls_certificate_checks.md) — if Beats input TLS is the error
→ [log_filtering](../../../../shared/log_filtering.md) — filter for input plugin name + error pattern

## KCS Queries
`"logstash kafka input lag consumer group fetch"`, `"beats input connection refused logstash"`, `"logstash file input sincedb not tailing"`, `"JDBC input logstash driver ClassNotFoundException"`

## Output
Report: input plugin type, error (bind/TLS/sincedb/driver), root cause, fix steps.
