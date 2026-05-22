---
name: eck-scheduling-nodes-resources
description: Diagnose pod scheduling, resource constraints, and affinity issues.
---
# ECK Scheduling & Resources

**Purpose:** Diagnose pod scheduling, resource constraints, and affinity issues.

**Use When:**
- Pods pending
- Insufficient CPU/Memory
- Affinity rules blocking

**Do Not Use When:**
- PVC pending (storage)

**Inputs Needed:**
- Pod events
- Node capacity
- Affinity rules

**Steps:**
1. Check pending pod events for scheduling failures.
2. Compare requested resources with available node capacity.
3. Review affinity, anti-affinity, taints, and tolerations.
4. Check Pod Disruption Budgets (PDB) blocking evictions.

**Output:**
- Identify scheduling constraint and recommended resolution.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
