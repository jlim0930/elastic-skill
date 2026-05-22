---
name: eck-autoscaling
description: Diagnose ECK autoscaling and resource recommendation issues.
---
# ECK Autoscaling

**Purpose:** Diagnose ECK autoscaling and resource recommendation issues.

**Use When:**
- Autoscaling not triggering
- Recommendations not applied

**Do Not Use When:**
- Manual scaling issues

**Inputs Needed:**
- Autoscaling policy
- Operator logs

**Steps:**
1. Check autoscaling policy in Elasticsearch CR.
2. Verify operator logs for autoscaling metrics and decisions.
3. Confirm Kubernetes Cluster Autoscaler interaction if node scaling is expected.

**Output:**
- Identify why autoscaling is failing and recommended configuration.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
