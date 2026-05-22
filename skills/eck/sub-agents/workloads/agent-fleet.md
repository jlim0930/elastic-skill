---
name: eck-agent-fleet
description: Diagnose Elastic Agent and Fleet Server issues on ECK.
---
# ECK Agent & Fleet

**Purpose:** Diagnose Elastic Agent and Fleet Server issues on ECK.

**Use When:**
- Agent not enrolling
- Fleet Server not starting
- Policy not applying

**Do Not Use When:**
- Standalone Beats issues outside ECK

**Inputs Needed:**
- Agent pod status
- Fleet Server status
- Logs

**Steps:**
1. Check Agent and Fleet Server pod status and logs (refer to `../../../../shared/log_filtering.md`).
2. Verify connectivity to Fleet Server and Elasticsearch (refer to `../../../../shared/network_connectivity_checks.md`).
3. Check applied Agent policy configuration.
4. Confirm pod security context allows required host access.

**Output:**
- Identify enrollment or connectivity blockers and recommended fix.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
