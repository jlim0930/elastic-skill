---
name: eck-storage-pvc-statefulset
description: Diagnose PVC binding, storage classes, and volume issues.
---
# ECK Storage & PVC

**Purpose:** Diagnose PVC binding, storage classes, and volume issues.

**Use When:**
- PVC pending
- Volume provisioning fails
- Disk expansion issues

**Do Not Use When:**
- Pod scheduling due to CPU/Memory

**Inputs Needed:**
- PVC status
- StorageClass config
- Pod events

**Steps:**
1. Check PVC and PV status for binding issues.
2. Confirm StorageClass configuration and provisioner availability.
3. Check init container logs for volume permission or ownership errors.

**Output:**
- Identify storage provisioning or permission failure and recommended fix.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
