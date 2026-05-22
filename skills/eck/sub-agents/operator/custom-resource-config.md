---
name: eck-custom-resource-config
description: Diagnose invalid custom resource specs and manifest errors.
---
# ECK Custom Resource Configuration

**Purpose:** Diagnose invalid custom resource specs and manifest errors.

**Use When:**
- CR validation fails
- Manifest errors
- Resource association failures

**Do Not Use When:**
- Pod scheduling issues
- Performance issues

**Inputs Needed:**
- CR manifest
- Error messages from apply

**Steps:**
1. Validate manifest against CRD schema (refer to `../../../../shared/config_filtering.md`).
2. Confirm resource associations point to valid, existing resources.
3. Check existence of referenced secrets and configmaps.
4. Validate nodeSets and roles configuration.

**Output:**
- Identify invalid manifest fields and suggest corrections.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
