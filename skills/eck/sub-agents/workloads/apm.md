---
name: eck-apm
description: Diagnose APM Server health and ingestion issues on ECK.
---
# ECK APM

**Purpose:** Diagnose APM Server health and ingestion issues on ECK.

**Use When:**
- APM server unhealthy
- Intake unavailable
- Association failing

**Do Not Use When:**
- Application-side APM agent issues

**Inputs Needed:**
- APM pod status
- Association status
- Logs

**Steps:**
1. Check APM pod status and logs.
2. Verify Elasticsearch association status in APM CR.
3. Confirm intake endpoint availability and exposure (refer to `../../../../shared/network_connectivity_checks.md`).

**Output:**
- Identify APM Server failure root cause and recommended fix.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
