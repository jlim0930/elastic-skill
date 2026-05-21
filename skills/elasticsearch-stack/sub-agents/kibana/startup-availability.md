---
name: kb-startup-availability
description: Diagnoses Kibana cannot start, saved object migration failures during upgrade, .kibana index health issues, version mismatch with Elasticsearch, task manager startup problems, and encryption key misconfiguration.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# KB — Startup & Availability

**Purpose**: Identify why Kibana cannot start or is not ready, and prescribe the fix.

## Use When
- Kibana service not starting or crashing on startup
- Saved object migration stuck or failed during upgrade
- `Kibana is not ready yet` in Status API
- Encryption key missing or changed

## Do Not Use When
- Kibana starts but login fails → kibana/login-authentication
- Kibana starts but specific feature unavailable → kibana/authorization-spaces

## Inputs Needed
- FATAL/ERROR lines from `kibana.log` at startup
- Kibana version and Elasticsearch version
- `.kibana` index health status
- Migration failure stage if upgrade in progress

## Diagnostic Logic

### Error Classification
| Pattern | Cause | Fix |
|---|---|---|
| `FATAL: Unable to complete migration` | Unrecoverable migration state | Delete partial migration index; restart |
| `REINDEX_FAILED` | ES reindex failed during upgrade | Fix ES cluster health first |
| `Stuck at WAIT_FOR_YELLOW_SOURCE` | `.kibana` index is RED | Fix `.kibana` shard allocation in ES |
| `Unable to retrieve version information` | ES unreachable | Check ES connectivity and credentials |
| `encryption key missing` | `xpack.encryptedSavedObjects.encryptionKey` not set | Add persistent 32+ char key |

### Migration Stages (Upgrade Process)
```
INIT → WAIT_FOR_YELLOW_SOURCE → REINDEX → CLONE_TEMP_TO_TARGET → UPDATE_TARGET_MAPPINGS → UPDATE_ALIASES → DONE
```
- Identify which stage is stuck/failed from log messages
- Most stages require healthy ES cluster to proceed

### Migration Unblock (Last Resort)
- Find and delete the partially created `.kibana_<version>_001` index
- Restart Kibana to retry migration from scratch
- Always backup `.kibana` before deleting migration artifacts

### .kibana Index Health
- `RED` health → primary shard not allocated → migration blocked; fix ES first
- `read_only_allow_delete: true` → disk flood-stage triggered → free disk, clear block
- Check index blocks setting before assuming migration failure is code-related

### Version Mismatch
- Kibana major.minor must match Elasticsearch major.minor exactly
- Kibana 8.5 cannot connect to ES 8.4 or 8.6
- Check both versions before any other startup troubleshooting

### Encryption Key Requirements
- `xpack.encryptedSavedObjects.encryptionKey` — required for connectors/alerts with secrets
- `xpack.reporting.encryptionKey` — required for reporting
- `xpack.security.encryptionKey` — required for session security
- Changing any key = all previously encrypted saved objects become permanently unreadable
- Must be identical across all Kibana nodes in a cluster

### Task Manager Startup
- Task manager drives all background jobs: alerting, reporting, ML
- Task manager failure → alerting, reporting, all background jobs stop
- Task manager requires healthy `.kibana_task_manager` index
- Fix ES cluster health for that index before diagnosing task manager further

### Kibana Node.js Memory
- Default max heap: ~1.4 GB
- OOM on startup: increase via `node.options: ["--max-old-space-size=2048"]`
- Maximum safe: ~50% of system RAM

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter startup log for FATAL/ERROR lines
→ [network_connectivity_checks](../../../../shared/network_connectivity_checks.md) — verify ES reachable from Kibana

## KCS Queries
`"kibana failed to start migration REINDEX"`, `"kibana .kibana index red migration blocked"`, `"kibana version mismatch elasticsearch"`, `"kibana encryption key missing connectors"`

## Output
Report: startup error type, migration stage (if applicable), ES health status of `.kibana`, fix steps.
