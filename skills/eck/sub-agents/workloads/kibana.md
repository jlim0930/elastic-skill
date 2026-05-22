---
name: eck-kibana
description: Diagnose Kibana startup, association, and migration issues on ECK.
---
# ECK Kibana

**Purpose:** Diagnose Kibana startup, association, and migration issues on ECK.

**Use When:**
- Kibana not starting
- Association failing
- Saved object migration issues

**Do Not Use When:**
- Elasticsearch cluster is red/down

**Inputs Needed:**
- Kibana pod status
- Association status
- Logs

**Steps:**
1. Check Kibana pod status and readiness probes.
2. Verify Elasticsearch association status in Kibana CR.
3. Check logs for migration or connectivity errors.
4. Confirm service and ingress exposure.

**Output:**
- Identify Kibana failure root cause and recommended resolution.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
