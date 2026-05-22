---
name: eck-performance-capacity
description: Diagnose CPU, memory, and IO performance bottlenecks on ECK.
---
# ECK Performance & Capacity

**Purpose:** Diagnose CPU, memory, and IO performance bottlenecks on ECK.

**Use When:**
- CPU throttling
- Heap pressure
- Disk IO bottlenecks
- Hot nodes

**Do Not Use When:**
- Application query logic issues outside of cluster resources

**Inputs Needed:**
- Cgroup stats
- JVM stats
- Node metrics

**Steps:**
1. Check for cgroup CPU throttling (refer to `../../../../shared/performance_triage.md`).
2. Monitor JVM heap usage and GC pauses.
3. Check node-level metrics for disk I/O wait.
4. Verify even shard distribution across nodes.

**Output:**
- Identify resource bottleneck and recommended sizing or configuration changes.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
