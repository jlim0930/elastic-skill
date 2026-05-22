---
name: eck-snapshot-repository
description: Diagnose snapshot backup and restore issues on ECK.
---
# ECK Snapshot & Repository

**Purpose:** Diagnose snapshot backup and restore issues on ECK.

**Use When:**
- Repository creation fails
- Snapshot fails
- Restore fails

**Do Not Use When:**
- Storage provisioning issues (PVC)

**Inputs Needed:**
- Repository secrets
- Snapshot status
- Logs

**Steps:**
1. Verify cloud credential secrets exist and are formatted correctly.
2. Check repository verification status (refer to `../../../../shared/snapshot_triage.md`).
3. Confirm volume mounts for local or shared storage.

**Output:**
- Identify repository or snapshot failure cause and recommended fix.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
