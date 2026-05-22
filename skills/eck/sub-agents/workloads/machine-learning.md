---
name: eck-machine-learning
description: Diagnose Machine Learning node and job issues on ECK.
---
# ECK Machine Learning

**Purpose:** Diagnose Machine Learning node and job issues on ECK.

**Use When:**
- ML nodes not scheduling
- ML jobs fail due to resources
- Native process failures

**Do Not Use When:**
- General search performance issues

**Inputs Needed:**
- ML node roles
- Resource limits
- Job status

**Steps:**
1. Verify ML roles are assigned in nodeSets.
2. Check container memory and resource limits.
3. Check ML job status and native process errors.

**Output:**
- Identify resource or configuration blockers for ML jobs.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
