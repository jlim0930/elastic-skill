---
name: eck-observability-diagnostics
description: Triage logs, events, and stack monitoring on ECK.
---
# ECK Observability & Diagnostics

**Purpose:** Triage logs, events, and stack monitoring on ECK.

**Use When:**
- Missing logs
- Monitoring not working
- Event correlation needed

**Do Not Use When:**
- Clear application errors with stack traces

**Inputs Needed:**
- Operator logs
- Kubernetes events
- Monitoring config

**Steps:**
1. Filter and analyze operator logs for warnings and errors (refer to `../../../../shared/log_filtering.md`).
2. Triage Kubernetes events and correlate with application logs.
3. Confirm stack monitoring configuration and index population.

**Output:**
- Identify missing visibility gaps and recommended diagnostic steps.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
