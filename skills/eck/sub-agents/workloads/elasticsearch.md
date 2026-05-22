---
name: eck-elasticsearch
description: Diagnose Elasticsearch cluster formation and configuration issues on ECK.
---
# ECK Elasticsearch

**Purpose:** Diagnose Elasticsearch cluster formation and configuration issues on ECK.

**Use When:**
- Cluster not forming
- Red/yellow health
- StatefulSet rollout issues

**Do Not Use When:**
- Kibana-only issues
- Networking-only issues

**Inputs Needed:**
- Cluster health
- Pod logs
- StatefulSet status

**Steps:**
1. Check cluster health and unassigned shards.
2. Check pod logs for startup or clustering errors (refer to `../../../../shared/log_filtering.md`).
3. Confirm PVCs are provisioned and bound.
4. Validate rendered configuration applied by operator.

**Output:**
- Identify cause of Elasticsearch workload failure and recommended fix.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
