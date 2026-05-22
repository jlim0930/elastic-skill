---
name: eck-operator-health-reconciliation
description: Diagnose ECK operator reconciliation failures and crash loops.
---
# ECK Operator Health & Reconciliation

**Purpose:** Diagnose ECK operator reconciliation failures and crash loops.

**Use When:**
- Operator not running
- Reconciliation stuck
- Webhook admission errors

**Do Not Use When:**
- Elasticsearch data issues
- Node scheduling issues

**Inputs Needed:**
- Operator pod status
- CR status phase
- Reconciliation events

**Steps:**
1. Check operator pod status and logs for errors (refer to `../../../../shared/log_filtering.md`).
2. Check custom resource status phase and conditions.
3. Verify webhook configuration and reachability.
4. Compare reconciliation loops with Kubernetes events.

**Output:**
- Identify root cause of operator failure and recommended fix.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
